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

import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

export interface LicenseUpdateEvent {
  type: 'identity_created' | 'identity_deleted' | 'identity_updated';
  data?: any;
}

@Injectable({
  providedIn: 'root'
})
export class LicenseEventsService {
  private licenseUpdateSubject = new Subject<LicenseUpdateEvent>();

  // 公開的 Observable，供組件訂閱
  public licenseUpdate$ = this.licenseUpdateSubject.asObservable();

  /**
   * 通知許可證狀態需要更新
   */
  notifyLicenseUpdate(event: LicenseUpdateEvent) {
    this.licenseUpdateSubject.next(event);
  }

  /**
   * 通知身份創建事件
   */
  notifyIdentityCreated(identityData?: any) {
    this.notifyLicenseUpdate({
      type: 'identity_created',
      data: identityData
    });
  }

  /**
   * 通知身份刪除事件
   */
  notifyIdentityDeleted(identityData?: any) {
    this.notifyLicenseUpdate({
      type: 'identity_deleted',
      data: identityData
    });
  }

  /**
   * 通知身份更新事件
   */
  notifyIdentityUpdated(identityData?: any) {
    this.notifyLicenseUpdate({
      type: 'identity_updated',
      data: identityData
    });
  }
} 