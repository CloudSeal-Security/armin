/*
    Copyright NetFoundry Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { LicenseCheckService, LicenseConfig, LicenseCheckResult } from './license-check.service';
import { ZITI_DATA_SERVICE } from './ziti-data.service';
import { of } from 'rxjs';

describe('LicenseCheckService', () => {
  let service: LicenseCheckService;
  let mockZitiService: jasmine.SpyObj<any>;
  let mockHttp: jasmine.SpyObj<any>;

  const mockLicenseConfig: LicenseConfig = {
    number: 100,
    start_date: '2025-01-01',
    end_date: '2025-04-30',
    unlimited: false,
    description: 'Test License'
  };

  const mockUnlimitedLicenseConfig: LicenseConfig = {
    number: 100,
    start_date: '2025-01-01',
    end_date: '2025-04-30',
    unlimited: true,
    description: 'Unlimited Test License'
  };

  beforeEach(() => {
    mockZitiService = jasmine.createSpyObj('ZitiDataService', ['call']);
    mockHttp = jasmine.createSpyObj('HttpClient', ['get']);

    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [
        LicenseCheckService,
        { provide: ZITI_DATA_SERVICE, useValue: mockZitiService },
        { provide: 'HttpClient', useValue: mockHttp }
      ]
    });

    service = TestBed.inject(LicenseCheckService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  describe('loadLicenseConfig', () => {
    it('should load license config successfully', (done) => {
      mockHttp.get.and.returnValue(of(mockLicenseConfig));

      service.loadLicenseConfig().subscribe(config => {
        expect(config).toEqual(mockLicenseConfig);
        expect(service.getLicenseConfig()).toEqual(mockLicenseConfig);
        done();
      });
    });

    it('should handle error and use default config', (done) => {
      mockHttp.get.and.returnValue(of(null).pipe(() => { throw new Error('Network error'); }));

      service.loadLicenseConfig().subscribe(config => {
        expect(config.unlimited).toBe(false);
        expect(config.number).toBe(100);
        done();
      });
    });
  });

  describe('canCreateIdentity', () => {
    beforeEach(() => {
      mockHttp.get.and.returnValue(of(mockLicenseConfig));
    });

    it('should allow creation when current count equals limit (not exceeded)', async () => {
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(10).fill({}).map((_, i) => ({
          id: `id-${i}`,
          name: `Identity ${i}`,
          typeId: 'User'
        }))
      }));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(true);
      expect(result.currentCount).toBe(10);
      expect(result.maxCount).toBe(10);
    });

    it('should prevent creation when current count exceeds limit', async () => {
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(11).fill({}).map((_, i) => ({
          id: `id-${i}`,
          name: `Identity ${i}`,
          typeId: 'User'
        }))
      }));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(false);
      expect(result.currentCount).toBe(11);
      expect(result.maxCount).toBe(10);
      expect(result.reason).toContain('exceeded');
    });

    it('should allow creation when unlimited is true', async () => {
      mockHttp.get.and.returnValue(of(mockUnlimitedLicenseConfig));
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(200).fill({}).map((_, i) => ({ id: i, typeId: 'User', name: `User${i}` }))
      }));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(true);
      expect(result.isUnlimited).toBe(true);
    });

    it('should block creation when license expired', async () => {
      const expiredConfig = { ...mockLicenseConfig, end_date: '2024-01-01' };
      mockHttp.get.and.returnValue(of(expiredConfig));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(false);
      expect(result.licenseExpired).toBe(true);
      expect(result.reason).toContain('License has expired');
    });

    it('should block creation when license not started', async () => {
      const futureConfig = { ...mockLicenseConfig, start_date: '2026-01-01' };
      mockHttp.get.and.returnValue(of(futureConfig));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(false);
      expect(result.licenseNotStarted).toBe(true);
      expect(result.reason).toContain('License is not active yet');
    });

    it('should exclude Router and Default Admin from count', async () => {
      const mockConfig: LicenseConfig = {
        unlimited: false,
        number: 5,
        start_date: '2025-01-01',
        end_date: '2025-12-31',
        description: 'Test License'
      };

      // Mock license config loading
      spyOn(service, 'loadLicenseConfig').and.returnValue({
        toPromise: () => Promise.resolve(mockConfig)
      } as any);

      // Mock identities including Router and Default Admin
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: [
          { id: '1', name: 'User1', typeId: 'User' },
          { id: '2', name: 'User2', typeId: 'User' },
          { id: '3', name: 'Router1', typeId: 'Router' },
          { id: '4', name: 'Default Admin', typeId: 'User' },
          { id: '5', name: 'User3', typeId: 'User' }
        ]
      }));

      const result = await service.canCreateIdentity();

      // Should only count 3 valid identities (User1, User2, User3)
      expect(result.currentCount).toBe(3);
      expect(result.canCreate).toBe(true);
    });

    it('should prevent creation when current count equals limit (10/10)', async () => {
      const mockConfig: LicenseConfig = {
        unlimited: false,
        number: 10,
        start_date: '2025-01-01',
        end_date: '2025-12-31',
        description: 'Test License'
      };

      // Mock license config loading
      spyOn(service, 'loadLicenseConfig').and.returnValue({
        toPromise: () => Promise.resolve(mockConfig)
      } as any);

      // Mock identities count - exactly at limit
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(10).fill({}).map((_, i) => ({
          id: `id-${i}`,
          name: `Identity ${i}`,
          typeId: 'User'
        }))
      }));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(false);
      expect(result.currentCount).toBe(10);
      expect(result.maxCount).toBe(10);
      expect(result.reason).toContain('reached');
    });

    it('should prevent creation when current count exceeds limit (11/10)', async () => {
      const mockConfig: LicenseConfig = {
        unlimited: false,
        number: 10,
        start_date: '2025-01-01',
        end_date: '2025-12-31',
        description: 'Test License'
      };

      // Mock license config loading
      spyOn(service, 'loadLicenseConfig').and.returnValue({
        toPromise: () => Promise.resolve(mockConfig)
      } as any);

      // Mock identities count - exceeding limit
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(11).fill({}).map((_, i) => ({
          id: `id-${i}`,
          name: `Identity ${i}`,
          typeId: 'User'
        }))
      }));

      const result = await service.canCreateIdentity();

      expect(result.canCreate).toBe(false);
      expect(result.currentCount).toBe(11);
      expect(result.maxCount).toBe(10);
      expect(result.reason).toContain('reached');
    });
  });

  describe('isUnlimited', () => {
    it('should return true for unlimited license', () => {
      mockHttp.get.and.returnValue(of(mockUnlimitedLicenseConfig));
      
      service.loadLicenseConfig().subscribe(() => {
        expect(service.isUnlimited()).toBe(true);
      });
    });

    it('should return false for limited license', () => {
      mockHttp.get.and.returnValue(of(mockLicenseConfig));
      
      service.loadLicenseConfig().subscribe(() => {
        expect(service.isUnlimited()).toBe(false);
      });
    });
  });

  describe('getRemainingIdentitiesCount', () => {
    it('should return correct remaining count when under limit', async () => {
      const mockConfig: LicenseConfig = {
        unlimited: false,
        number: 10,
        start_date: '2025-01-01',
        end_date: '2025-12-31',
        description: 'Test License'
      };

      spyOn(service, 'loadLicenseConfig').and.returnValue({
        toPromise: () => Promise.resolve(mockConfig)
      } as any);

      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(7).fill({}).map((_, i) => ({
          id: `id-${i}`,
          name: `Identity ${i}`,
          typeId: 'User'
        }))
      }));

      const remaining = await service.getRemainingIdentitiesCount();
      expect(remaining).toBe(3); // 10 - 7 = 3
    });

    it('should return large number when unlimited', async () => {
      const mockConfig: LicenseConfig = {
        unlimited: true,
        number: 10,
        start_date: '2025-01-01',
        end_date: '2025-12-31',
        description: 'Test License'
      };

      spyOn(service, 'loadLicenseConfig').and.returnValue({
        toPromise: () => Promise.resolve(mockConfig)
      } as any);

      const remaining = await service.getRemainingIdentitiesCount();
      expect(remaining).toBe(999999);
    });
  });

  describe('getCurrentIdentitiesCount', () => {
    it('should return correct current count', async () => {
      mockZitiService.call.and.returnValue(Promise.resolve({
        data: Array(25).fill({}).map((_, i) => ({ id: i, typeId: 'User', name: `User${i}` }))
      }));

      const count = await service.getCurrentIdentitiesCount();
      expect(count).toBe(25);
    });
  });
}); 