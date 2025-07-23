import { Injectable, Inject } from '@angular/core';
import { ZITI_DATA_SERVICE } from '../../services/ziti-data.service';
import { ZitiDataService } from '../../services/ziti-data.service';
import { LicenseCheckService } from '../../services/license-check.service';

@Injectable({
  providedIn: 'root'
})
export class IdentitiesFormService {

  constructor(
    @Inject(ZITI_DATA_SERVICE) private zitiService: ZitiDataService,
    private licenseCheckService: LicenseCheckService
  ) {}

  async createIdentity(identity: any): Promise<any> {
    // 檢查許可證限制
    const licenseCheck = await this.licenseCheckService.canCreateIdentity();
    
    if (!licenseCheck.canCreate) {
      throw new Error(licenseCheck.reason || 'License check failed');
    }

    // 如果是無限制模式，只檢查時間限制
    if (licenseCheck.isUnlimited) {
      console.log('Unlimited license mode - skipping identity count check');
    } else {
      console.log(`License check passed. Current: ${licenseCheck.currentCount}, Max: ${licenseCheck.maxCount}`);
    }

    try {
      const response = await this.zitiService.post('identities', identity);
      return response;
    } catch (error) {
      console.error('Error creating identity:', error);
      throw error;
    }
  }
} 