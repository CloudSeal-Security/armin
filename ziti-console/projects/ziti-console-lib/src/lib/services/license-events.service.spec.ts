import { TestBed } from '@angular/core/testing';
import { LicenseEventsService, LicenseUpdateEvent } from './license-events.service';

describe('LicenseEventsService', () => {
  let service: LicenseEventsService;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [LicenseEventsService]
    });
    service = TestBed.inject(LicenseEventsService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should notify identity created event', (done) => {
    const testData = { id: '1', name: 'Test Identity' };
    
    service.licenseUpdate$.subscribe((event: LicenseUpdateEvent) => {
      expect(event.type).toBe('identity_created');
      expect(event.data).toEqual(testData);
      done();
    });

    service.notifyIdentityCreated(testData);
  });

  it('should notify identity deleted event', (done) => {
    const testData = [{ id: '1', name: 'Test Identity' }];
    
    service.licenseUpdate$.subscribe((event: LicenseUpdateEvent) => {
      expect(event.type).toBe('identity_deleted');
      expect(event.data).toEqual(testData);
      done();
    });

    service.notifyIdentityDeleted(testData);
  });

  it('should notify identity updated event', (done) => {
    const testData = { id: '1', name: 'Updated Identity' };
    
    service.licenseUpdate$.subscribe((event: LicenseUpdateEvent) => {
      expect(event.type).toBe('identity_updated');
      expect(event.data).toEqual(testData);
      done();
    });

    service.notifyIdentityUpdated(testData);
  });

  it('should notify generic license update event', (done) => {
    const testEvent: LicenseUpdateEvent = {
      type: 'identity_created',
      data: { id: '1', name: 'Test' }
    };
    
    service.licenseUpdate$.subscribe((event: LicenseUpdateEvent) => {
      expect(event).toEqual(testEvent);
      done();
    });

    service.notifyLicenseUpdate(testEvent);
  });
}); 