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

import { Component, OnInit, OnDestroy } from '@angular/core';
import { LicenseCheckService, LicenseConfig } from '../../services/license-check.service';
import { LicenseEventsService } from '../../services/license-events.service';
import { Subscription } from 'rxjs';
import { Router, NavigationEnd } from '@angular/router';

@Component({
  selector: 'lib-license-status',
  templateUrl: './license-status.component.html',
  styleUrls: ['./license-status.component.scss']
})
export class LicenseStatusComponent implements OnInit, OnDestroy {
  
  licenseConfig: LicenseConfig | null = null;
  remainingCount: number = 0;
  currentCount: number = 0;
  maxCount: number = 0;
  isLicenseExpired: boolean = false;
  isLicenseNotStarted: boolean = false;
  isUnlimited: boolean = false;
  isLoading: boolean = true;
  
  private subscription = new Subscription();
  private routerSubscription: Subscription;

  constructor(
    private licenseCheckService: LicenseCheckService,
    private licenseEventsService: LicenseEventsService,
    private router: Router
  ) {}

  ngOnInit() {
    this.loadLicenseInfo();
    
    // 監聽許可證更新事件
    this.subscription.add(
      this.licenseEventsService.licenseUpdate$.subscribe(event => {
        console.log('License status update event received:', event);
        this.refreshLicenseInfo();
      })
    );
    // 監聽路由切換事件
    this.routerSubscription = this.router.events.subscribe(event => {
      if (event instanceof NavigationEnd) {
        this.refreshLicenseInfo();
      }
    });
  }

  ngOnDestroy() {
    this.subscription.unsubscribe();
    if (this.routerSubscription) {
      this.routerSubscription.unsubscribe();
    }
  }

  async loadLicenseInfo() {
    try {
      this.isLoading = true;
      
      // 載入許可證配置
      this.subscription.add(
        this.licenseCheckService.loadLicenseConfig().subscribe(config => {
          this.licenseConfig = config;
          this.maxCount = config.number;
          this.isUnlimited = config.unlimited;
        })
      );

      // 獲取當前身份數量
      this.currentCount = await this.licenseCheckService.getCurrentIdentitiesCount();
      
      // 獲取剩餘身份數量
      this.remainingCount = await this.licenseCheckService.getRemainingIdentitiesCount();

      // 檢查許可證狀態
      this.isLicenseExpired = this.licenseCheckService.isLicenseExpired();
      this.isLicenseNotStarted = this.licenseCheckService.isLicenseNotStarted();

    } catch (error) {
      console.error('Error loading license info:', error);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 刷新許可證信息（用於事件觸發的更新）
   */
  async refreshLicenseInfo() {
    try {
      // 獲取當前身份數量
      this.currentCount = await this.licenseCheckService.getCurrentIdentitiesCount();
      
      // 獲取剩餘身份數量
      this.remainingCount = await this.licenseCheckService.getRemainingIdentitiesCount();

      // 檢查許可證狀態
      this.isLicenseExpired = this.licenseCheckService.isLicenseExpired();
      this.isLicenseNotStarted = this.licenseCheckService.isLicenseNotStarted();

      console.log('License info refreshed:', {
        currentCount: this.currentCount,
        maxCount: this.maxCount,
        remainingCount: this.remainingCount,
        status: this.getStatusText()
      });

    } catch (error) {
      console.error('Error refreshing license info:', error);
    }
  }

  getStatusClass(): string {
    if (this.isLicenseExpired) {
      return 'license-expired';
    }
    if (this.isLicenseNotStarted) {
      return 'license-not-started';
    }
    if (this.isUnlimited) {
      return 'license-unlimited';
    }
    if (this.currentCount >= this.maxCount) {
      return 'license-limit-reached';
    }
  
    if (this.remainingCount <= 3 && this.currentCount < this.maxCount) {
      return 'license-warning';
    }
    return 'license-ok';
  }

  getStatusText(): string {
    if (this.isLicenseExpired) {
      return 'Expired';
    }
    if (this.isLicenseNotStarted) {
      return 'Not Active';
    }
    if (this.isUnlimited) {
      return 'Unlimited';
    }
    if (this.currentCount >= this.maxCount) {
      return 'Reached';
    }
  
    if (this.remainingCount <= 3 && this.currentCount < this.maxCount) {
      return 'Low Quota';
    }
    return 'Active';
  }

  getProgressPercentage(): number {
    if (this.isUnlimited) {
      return 0; // 無限制模式不顯示進度條
    }
    if (this.maxCount === 0) return 0;
    return (this.currentCount / this.maxCount) * 100;
  }

  getDisplayText(): string {
    if (this.isUnlimited) {
      return '∞'; // 無限符號
    }
    return `${this.currentCount} / ${this.maxCount}`;
  }

  getTimeDisplayText(): string {
    if (this.isUnlimited) {
      return 'Infinite Time';
    }
    if (this.licenseConfig) {
      return `${this.licenseConfig.start_date} - ${this.licenseConfig.end_date}`;
    }
    return '';
  }
} 