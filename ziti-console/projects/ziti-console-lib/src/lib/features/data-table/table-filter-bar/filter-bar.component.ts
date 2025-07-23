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

import {Component, Input} from '@angular/core';
import {debounce, isNumber} from "lodash";
import {DataTableFilterService, FilterObj} from "../data-table-filter.service";

@Component({
  selector: 'lib-table-filter-bar',
  templateUrl: './filter-bar.component.html',
  styleUrls: ['./filter-bar.component.scss']
})
export class FilterBarComponent {

  _filters = [];

  @Input() filterName: string = 'name';
  @Input() filterColumn: string = 'name';

  @Input() startCount: string = '-';
  @Input() endCount: string = '-';
  @Input() totalCount: string = '-';

  filtering = false;
  filterString = '';
  inputChangedDebounced = debounce(this.inputChanged.bind(this), 400);

  constructor(public filterService: DataTableFilterService) {
    this.filterService.filtersChanged.subscribe(filters => {
      this._filters = filters.filter((filter: any) => {
        return filter.hidden !== true;
      });
      let tmp = '';
      for (let idx = 0; idx < filters.length; idx++) {
        if (filters[idx].columnId === this.filterColumn) {
          tmp = filters[idx].value;
          break;
        }
      }
      this.filterString = tmp;
    });
    this.filterService.filtering.subscribe((filtering) => {
      this.filtering = filtering;
    });
  }

  nextPage() {
    this.filterService.changePage(this.filterService.currentPage + 1);
  }

  prevPage() {
    this.filterService.changePage(this.filterService.currentPage - 1);
  }

  get nextDisabled() {
    const total = Number.parseInt(this.totalCount, 10);
    const end = Number.parseInt(this.endCount, 10);
    const isDisabled = !isNumber(total) || !isNumber(end) || this.filtering || end >= total;
    console.log(`[FilterBarComponent] nextDisabled check. total: ${total}, end: ${end}, filtering: ${this.filtering}, isDisabled: ${isDisabled}`);
    return isDisabled;
  }

  get prevDisabled() {
    if (!isNumber(this.startCount) || !isNumber(this.totalCount) || this.filtering) {
      return true;
    }
    const start = Number.parseInt(this.startCount, 10);
    return start <= 1;
  }

  inputChanged() {
    this.filterService.currentPage = 1;
    const filterObj: FilterObj = {
      filterName: this.filterName,
      columnId: this.filterColumn,
      value: this.filterString,
      label: this.filterString,
    };
    this.filterService.updateFilter(filterObj)
  }

  removeFilter(filterObj: FilterObj) {
    this.filterService.removeFilter(filterObj);
  }
}
