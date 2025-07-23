import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { LicenseStatusComponent } from './license-status.component';
import { LicenseCheckService } from '../../services/license-check.service';
import { ZITI_DATA_SERVICE } from '../../services/ziti-data.service';
import { of } from 'rxjs';

describe('LicenseStatusComponent', () => {
  let component: LicenseStatusComponent;
  let fixture: ComponentFixture<LicenseStatusComponent>;
  let mockZitiService: any;
  let mockLicenseService: jasmine.SpyObj<LicenseCheckService>;

  const mockLicenseConfig = {
    number: 100,
    start_date: '2025-01-01',
    end_date: '2025-04-30',
    unlimited: false,
    description: 'Test License'
  };

  const mockUnlimitedLicenseConfig = {
    number: 100,
    start_date: '2025-01-01',
    end_date: '2025-04-30',
    unlimited: true,
    description: 'Unlimited Test License'
  };

  beforeEach(async () => {
    mockZitiService = {
      call: jasmine.createSpy('call')
    };

    mockLicenseService = jasmine.createSpyObj('LicenseCheckService', [
      'loadLicenseConfig',
      'getCurrentIdentitiesCount',
      'getRemainingIdentitiesCount',
      'isLicenseExpired',
      'isLicenseNotStarted'
    ]);

    await TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      declarations: [ LicenseStatusComponent ],
      providers: [
        LicenseCheckService,
        { provide: ZITI_DATA_SERVICE, useValue: mockZitiService },
        { provide: LicenseCheckService, useValue: mockLicenseService }
      ]
    })
    .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(LicenseStatusComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should show loading state initially', () => {
    expect(component.isLoading).toBe(true);
  });

  it('should get correct status class for different states', () => {
    // Test license expired
    component.isLicenseExpired = true;
    expect(component.getStatusClass()).toBe('license-expired');

    // Test license not started
    component.isLicenseExpired = false;
    component.isLicenseNotStarted = true;
    expect(component.getStatusClass()).toBe('license-not-started');

    // Test limit reached
    component.isLicenseNotStarted = false;
    component.remainingCount = 0;
    expect(component.getStatusClass()).toBe('license-limit-reached');

    // Test warning
    component.remainingCount = 3;
    expect(component.getStatusClass()).toBe('license-warning');

    // Test ok
    component.remainingCount = 10;
    expect(component.getStatusClass()).toBe('license-ok');
  });

  it('should get correct status text for different states', () => {
    // Test license expired
    component.isLicenseExpired = true;
    expect(component.getStatusText()).toBe('License Expired');

    // Test license not started
    component.isLicenseExpired = false;
    component.isLicenseNotStarted = true;
    expect(component.getStatusText()).toBe('License Not Active');

    // Test limit reached
    component.isLicenseNotStarted = false;
    component.remainingCount = 0;
    expect(component.getStatusText()).toBe('Limit Reached');

    // Test warning
    component.remainingCount = 3;
    expect(component.getStatusText()).toBe('Low Quota');

    // Test ok
    component.remainingCount = 10;
    expect(component.getStatusText()).toBe('Active');
  });

  it('should calculate progress percentage correctly', () => {
    component.maxCount = 100;
    component.currentCount = 75;
    expect(component.getProgressPercentage()).toBe(75);

    component.currentCount = 0;
    expect(component.getProgressPercentage()).toBe(0);

    component.maxCount = 0;
    expect(component.getProgressPercentage()).toBe(0);
  });

  describe('loadLicenseInfo', () => {
    it('should load license information successfully', async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);

      await component.loadLicenseInfo();

      expect(component.licenseConfig).toEqual(mockLicenseConfig);
      expect(component.currentCount).toBe(50);
      expect(component.remainingCount).toBe(50);
      expect(component.maxCount).toBe(100);
      expect(component.isUnlimited).toBe(false);
      expect(component.isLoading).toBe(false);
    });

    it('should handle unlimited license correctly', async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockUnlimitedLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(200));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(999999));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);

      await component.loadLicenseInfo();

      expect(component.isUnlimited).toBe(true);
      expect(component.remainingCount).toBe(999999);
    });
  });

  describe('getStatusClass', () => {
    beforeEach(async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);
      await component.loadLicenseInfo();
    });

    it('should return license-ok for normal status', () => {
      expect(component.getStatusClass()).toBe('license-ok');
    });

    it('should return license-warning when remaining count is low', async () => {
      component.remainingCount = 3;
      expect(component.getStatusClass()).toBe('license-warning');
    });

    it('should return license-limit-reached when no remaining count', async () => {
      component.remainingCount = 0;
      expect(component.getStatusClass()).toBe('license-limit-reached');
    });

    it('should return license-expired when license is expired', async () => {
      component.isLicenseExpired = true;
      expect(component.getStatusClass()).toBe('license-expired');
    });

    it('should return license-not-started when license not started', async () => {
      component.isLicenseNotStarted = true;
      expect(component.getStatusClass()).toBe('license-not-started');
    });

    it('should return license-unlimited for unlimited license', async () => {
      component.isUnlimited = true;
      expect(component.getStatusClass()).toBe('license-unlimited');
    });
  });

  describe('getStatusText', () => {
    beforeEach(async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);
      await component.loadLicenseInfo();
    });

    it('should return Active for normal status', () => {
      expect(component.getStatusText()).toBe('Active');
    });

    it('should return Low Quota when remaining count is low', () => {
      component.remainingCount = 3;
      expect(component.getStatusText()).toBe('Low Quota');
    });

    it('should return Limit Reached when no remaining count', () => {
      component.remainingCount = 0;
      expect(component.getStatusText()).toBe('Limit Reached');
    });

    it('should return License Expired when license is expired', () => {
      component.isLicenseExpired = true;
      expect(component.getStatusText()).toBe('License Expired');
    });

    it('should return License Not Active when license not started', () => {
      component.isLicenseNotStarted = true;
      expect(component.getStatusText()).toBe('License Not Active');
    });

    it('should return Unlimited for unlimited license', () => {
      component.isUnlimited = true;
      expect(component.getStatusText()).toBe('Unlimited');
    });

    it('should show Low Quota when remaining count is less than 5', () => {
      component.isUnlimited = false;
      component.currentCount = 8;
      component.maxCount = 10;
      component.remainingCount = 2;
      expect(component.getStatusText()).toBe('Low Quota');
    });

    it('should show Active when remaining count is 5 or more', () => {
      component.isUnlimited = false;
      component.currentCount = 5;
      component.maxCount = 10;
      component.remainingCount = 5;
      expect(component.getStatusText()).toBe('Active');
    });

    it('should show Limit Reached when current count equals max count (10/10)', () => {
      component.isUnlimited = false;
      component.currentCount = 10;
      component.maxCount = 10;
      component.remainingCount = 0;
      expect(component.getStatusText()).toBe('Limit Reached');
      expect(component.getStatusClass()).toBe('license-limit-reached');
    });

    it('should show Limit Reached when current count exceeds max count (11/10)', () => {
      component.isUnlimited = false;
      component.currentCount = 11;
      component.maxCount = 10;
      component.remainingCount = 0;
      expect(component.getStatusText()).toBe('Limit Reached');
      expect(component.getStatusClass()).toBe('license-limit-reached');
    });
  });

  describe('getProgressPercentage', () => {
    beforeEach(async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);
      await component.loadLicenseInfo();
    });

    it('should return correct percentage for limited license', () => {
      expect(component.getProgressPercentage()).toBe(50); // 50/100 = 50%
    });

    it('should return 0 for unlimited license', () => {
      component.isUnlimited = true;
      expect(component.getProgressPercentage()).toBe(0);
    });

    it('should return 0 when maxCount is 0', () => {
      component.maxCount = 0;
      expect(component.getProgressPercentage()).toBe(0);
    });
  });

  describe('getDisplayText', () => {
    beforeEach(async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);
      await component.loadLicenseInfo();
    });

    it('should return formatted count for limited license', () => {
      expect(component.getDisplayText()).toBe('50 / 100');
    });

    it('should return infinity symbol for unlimited license', () => {
      component.isUnlimited = true;
      expect(component.getDisplayText()).toBe('∞');
    });
  });

  describe('getTimeDisplayText', () => {
    beforeEach(async () => {
      mockLicenseService.loadLicenseConfig.and.returnValue(of(mockLicenseConfig));
      mockLicenseService.getCurrentIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.getRemainingIdentitiesCount.and.returnValue(Promise.resolve(50));
      mockLicenseService.isLicenseExpired.and.returnValue(false);
      mockLicenseService.isLicenseNotStarted.and.returnValue(false);
      await component.loadLicenseInfo();
    });

    it('should return formatted date range for limited license', () => {
      expect(component.getTimeDisplayText()).toBe('2025-01-01 - 2025-04-30');
    });

    it('should return Infinite Time for unlimited license', () => {
      component.isUnlimited = true;
      expect(component.getTimeDisplayText()).toBe('Infinite Time');
    });

    it('should return empty string when no license config', () => {
      component.licenseConfig = null;
      expect(component.getTimeDisplayText()).toBe('');
    });
  });
}); 