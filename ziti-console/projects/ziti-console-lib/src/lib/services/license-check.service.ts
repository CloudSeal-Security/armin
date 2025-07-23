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

import { Injectable, Inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of, throwError } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { ZITI_DATA_SERVICE, ZitiDataService } from './ziti-data.service';
import moment from 'moment';

export interface LicenseConfig {
  number: number;
  start_date: string;
  end_date: string;
  unlimited: boolean;
  description: string;
}

export interface LicenseCheckResult {
  canCreate: boolean;
  reason?: string;
  currentCount?: number;
  maxCount?: number;
  licenseExpired?: boolean;
  licenseNotStarted?: boolean;
  isUnlimited?: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class LicenseCheckService {

  private licenseConfig: LicenseConfig | null = null;

  constructor(
    @Inject(ZITI_DATA_SERVICE) private zitiService: ZitiDataService,
    private http: HttpClient
  ) {}

  /**
   * 載入許可證配置
   */
  loadLicenseConfig(): Observable<LicenseConfig> {
    return this.http.get<LicenseConfig>('/assets/data/license_number.json').pipe(
      map(config => {
        this.licenseConfig = config;
        return config;
      }),
      catchError(error => {
        console.error('Failed to load license config:', error);
        // 如果無法載入許可證配置，使用預設值
        this.licenseConfig = {
          number: 100,
          start_date: '2025-01-01',
          end_date: '2025-04-30',
          unlimited: false,
          description: 'Default License Configuration'
        };
        return of(this.licenseConfig);
      })
    );
  }

  /**
   * 檢查是否可以創建新的身份
   */
  async canCreateIdentity(): Promise<LicenseCheckResult> {
    if (!this.licenseConfig) {
      await this.loadLicenseConfig().toPromise();
    }

    const result: LicenseCheckResult = {
      canCreate: true,
      isUnlimited: this.licenseConfig!.unlimited
    };

    // 如果是無限制模式，跳過數量檢查
    if (this.licenseConfig!.unlimited) {
      // 只檢查使用期限
      const now = moment();
      const startDate = moment(this.licenseConfig!.start_date);
      const endDate = moment(this.licenseConfig!.end_date);

      if (now.isBefore(startDate)) {
        result.canCreate = false;
        result.licenseNotStarted = true;
        result.reason = `License is not active yet. License starts from ${this.licenseConfig!.start_date}`;
        return result;
      }

      if (now.isAfter(endDate)) {
        result.canCreate = false;
        result.licenseExpired = true;
        result.reason = `License has expired. License expired on ${this.licenseConfig!.end_date}`;
        return result;
      }

      return result;
    }

    // 有限制模式：檢查使用期限和數量限制
    const now = moment();
    const startDate = moment(this.licenseConfig!.start_date);
    const endDate = moment(this.licenseConfig!.end_date);

    if (now.isBefore(startDate)) {
      result.canCreate = false;
      result.licenseNotStarted = true;
      result.reason = `License is not active yet. License starts from ${this.licenseConfig!.start_date}`;
      return result;
    }

    if (now.isAfter(endDate)) {
      result.canCreate = false;
      result.licenseExpired = true;
      result.reason = `License has expired. License expired on ${this.licenseConfig!.end_date}`;
      return result;
    }

    // 檢查身份數量限制
    try {
      const identities = await this.getValidIdentitiesCount();
      result.currentCount = identities;
      result.maxCount = this.licenseConfig!.number;

      if (identities >= this.licenseConfig!.number) {
        result.canCreate = false;
        result.reason = `Maximum number of identities (${this.licenseConfig!.number}) reached. Current count: ${identities}`;
      }
    } catch (error) {
      console.error('Failed to get identities count:', error);
      result.canCreate = false;
      result.reason = 'Failed to verify identity count limit';
    }

    return result;
  }

  /**
   * 獲取有效的身份數量（排除Router和default admin類型）
   */
  private async getValidIdentitiesCount(): Promise<number> {
    try {
      const response = await this.zitiService.call('/identities?limit=1000');
      const identities = response.data || [];
      
      // 過濾掉Router類型和default admin身份
      const validIdentities = identities.filter((identity: any) => {
        // 排除Router類型
        if (identity.typeId === 'Router' || identity.type?.name === 'Router') {
          return false;
        }
        
        // 排除default admin
        if (identity.name === 'Default Admin') {
          return false;
        }
        
        return true;
      });

      return validIdentities.length;
    } catch (error) {
      console.error('Error fetching identities:', error);
      throw error;
    }
  }

  /**
   * 獲取許可證配置
   */
  getLicenseConfig(): LicenseConfig | null {
    return this.licenseConfig;
  }

  /**
   * 檢查許可證是否過期
   */
  isLicenseExpired(): boolean {
    if (!this.licenseConfig) {
      return false;
    }
    const now = moment();
    const endDate = moment(this.licenseConfig.end_date);
    return now.isAfter(endDate);
  }

  /**
   * 檢查許可證是否尚未開始
   */
  isLicenseNotStarted(): boolean {
    if (!this.licenseConfig) {
      return false;
    }
    const now = moment();
    const startDate = moment(this.licenseConfig.start_date);
    return now.isBefore(startDate);
  }

  /**
   * 檢查是否為無限制模式
   */
  isUnlimited(): boolean {
    return this.licenseConfig?.unlimited || false;
  }

  /**
   * 獲取剩餘的有效身份數量
   */
  async getRemainingIdentitiesCount(): Promise<number> {
    if (!this.licenseConfig) {
      await this.loadLicenseConfig().toPromise();
    }
    
    // 如果是無限制模式，返回一個很大的數字
    if (this.licenseConfig!.unlimited) {
      return 999999;
    }
    
    const currentCount = await this.getValidIdentitiesCount();
    return Math.max(0, this.licenseConfig!.number - currentCount);
  }

  /**
   * 獲取當前身份數量
   */
  async getCurrentIdentitiesCount(): Promise<number> {
    return await this.getValidIdentitiesCount();
  }
} 