import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import {Subject} from "rxjs";
import {debounce} from "lodash";

@Component({
  selector: 'lib-password-input',
  template: `
      <div [ngClass]="fieldClass">
          <label for="schema_{{parentage?parentage+'_':''}}{{_idName}}" [ngStyle]="{'color': labelColor}">{{_fieldName}}</label>
          <div class="input-group">
              <input id="schema_{{parentage?parentage+'_':''}}{{_idName}}"
                     type="password" class="jsonEntry"
                     [required]="required"
                     [autocomplete]="autocomplete"
                     [ngClass]="{'error': error}"
                     [placeholder]="placeholder" [(ngModel)]="fieldValue" (paste)="onKeyup()" (keyup)="onKeyup()" (change)="emitEvents()"/>
          </div>
          <div *ngIf="error" class="error">{{error}}</div>
      </div>
  `,
    styles:[
      'input.error {border-color:red;}',
      'div.error {color:red}',
      '.input-group { display: flex; align-items: center; background: rgba(255, 255, 255, 0.1); border-radius: 8px; padding: 0.5rem; margin: 1rem 0; border: 1px solid rgba(255, 255, 255, 0.2); transition: all 0.3s ease; }',
      '.input-group:hover { background: rgba(255, 255, 255, 0.15); border-color: rgba(255, 255, 255, 0.3); }',
      'input { background: transparent; border: none; color: #ffffff !important; width: 100%; padding: 8px; font-size: 14px; }',
      'input::placeholder { color: rgba(255, 255, 255, 0.7) !important; }',
      'input:focus { outline: none; color: #ffffff !important; }',
      'input:-webkit-autofill, input:-webkit-autofill:hover, input:-webkit-autofill:focus { -webkit-text-fill-color: #ffffff !important; transition: background-color 5000s ease-in-out 0s; }'
    ]
})
export class PasswordInputComponent {
    _fieldName = 'Field Label';
    _idName = 'fieldname';
    @Input() set fieldName(name: string) {
        this._fieldName = name;
        this._idName = name.replace(/\s/g, '').toLowerCase();
    }
    @Input() fieldValue = '';
    @Input() placeholder = '';
    @Input() parentage: string[] = [];
    @Input() labelColor = '#000000';
    @Input() fieldClass = '';
    @Input() error = '';
    @Input() autocomplete = '';
    @Input() required = false;
    @Output() fieldValueChange = new EventEmitter<string>();
    valueChange = new Subject<string> ();

    onKeyup() {
        this.emitEventsDebounced();
    }

    emitEventsDebounced = debounce(this.emitEvents.bind(this), 500);
    emitEvents() {
        this.fieldValueChange.emit(this.fieldValue);
        this.valueChange.next(this.fieldValue);
    }
}
