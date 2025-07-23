import {Component} from "@angular/core";
import {ITooltipAngularComp} from "ag-grid-angular";
import {ITooltipParams} from "ag-grid-community";
import {isEmpty} from "lodash";

@Component({
    selector: 'lib-sdk-tooltip',
    template: `
      <div class="os-tooltip" [style.background-color]="color" [ngClass]="{hidden: hasData}">
          <p><span>APP ID: </span> <strong>{{ data.sdkInfo?.appId }}</strong></p>
          <p><span>Version: </span><strong>{{ data.sdkInfo?.appVersion }}</strong></p>
          <p><span>Branch: </span><strong>{{ data.sdkInfo?.branch }}</strong></p>
          <p><span>Revision: </span><strong>{{ data.sdkInfo?.revision }}</strong></p>
          <p><span>Type: </span><strong>{{ data.sdkInfo?.type }}</strong></p>
      </div>`,
    styles: [
        `
            .os-tooltip {
                padding: 10px 14px;
                background: #23272f;
                border: 1px solid #444c5e;
                border-radius: 8px;
                color: #fff;
                box-shadow: 0 4px 24px 0 rgba(0,0,0,0.45);
                min-width: 140px;
                font-size: 1rem;
            }

            :host {
                position: absolute;
                width: fit-content;
                min-width: 170px;
                min-height: 70px;
                pointer-events: none;
                transition: opacity 1s;
                z-index: 9999;
            }

            :host.ag-tooltip-hiding {
                opacity: 0;
            }

            .os-tooltip p {
                margin: 6px 0 6px 0;
                white-space: nowrap;
                color: #fff;
            }
            .os-tooltip span {
                color: #b0b8c9;
            }
            .os-tooltip strong {
                color: #fff;
                font-weight: 600;
            }
        `
    ]
})
export class SDKTooltipComponent implements ITooltipAngularComp {
    private params!: {color: string} & ITooltipParams;
    public data!: any;
    public color!: string;

    agInit(params: {color: string} & ITooltipParams): void {
        this.params = params;

        this.data = params.api.getDisplayedRowAtIndex(params.rowIndex).data;
    }

    get hasData() {
        return isEmpty(this.data?.sdkInfo?.version);
    }
}