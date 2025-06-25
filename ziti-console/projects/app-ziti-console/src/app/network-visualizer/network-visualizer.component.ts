import { Component, OnInit, ViewChild, ElementRef, AfterViewInit, ViewEncapsulation } from '@angular/core';
import * as d3 from 'd3';
import { ZitiDataService } from 'ziti-console-lib';

@Component({
  selector: 'app-network-visualizer',
  template: `
    <div class="network-visualizer-container">
      <div class="visualizer-header">
        <div class="title">Network Visualizer</div>
        <div class="controls">
          <button class="control-button refresh" (click)="refreshData()" [class.rotating]="isLoading">
            <i class="icon-refresh"></i>
          </button>
          <button class="control-button fullscreen" (click)="toggleFullscreen()">
            <i class="icon-fullscreen"></i>
          </button>
        </div>
      </div>
      
      <div class="visualizer-content" [class.fullscreen]="isFullscreen">
        <div class="filter-container">
          <input 
            type="text" 
            class="filter-input" 
            placeholder="Search nodes..." 
            [(ngModel)]="searchText"
            (keyup)="filterNodes()"
          />
        </div>
        
        <div class="visualizer-canvas" #visualizerCanvas>
          <svg #networkSvg></svg>
          <div class="tooltip" #tooltip></div>
        </div>

        <div class="legend">
          <div class="legend-title">Legend</div>
          <div class="legend-item">
            <div class="legend-icon router"></div>
            <div class="legend-text">Router</div>
          </div>
          <div class="legend-item">
            <div class="legend-icon service"></div>
            <div class="legend-text">Service</div>
          </div>
          <div class="legend-item">
            <div class="legend-icon identity"></div>
            <div class="legend-text">Identity</div>
          </div>
          <div class="legend-item">
            <div class="legend-icon connection"></div>
            <div class="legend-text">Connection</div>
          </div>
        </div>
      </div>
    </div>
  `,
  styleUrls: ['./network-visualizer.component.scss'],
  encapsulation: ViewEncapsulation.None
})
export class NetworkVisualizerComponent implements AfterViewInit {
  @ViewChild('networkSvg') svgElement: ElementRef;
  @ViewChild('visualizerCanvas') canvasElement: ElementRef;
  @ViewChild('tooltip') tooltipElement: ElementRef;

  private svg: any;
  private width: number;
  private height: number;
  private simulation: any;
  private nodes: any[] = [];
  private links: any[] = [];
  
  searchText: string = '';
  isLoading: boolean = false;
  isFullscreen: boolean = false;

  constructor(private zitiService: ZitiDataService) {}

  ngAfterViewInit() {
    this.initializeVisualizer();
    this.loadData();
  }

  private initializeVisualizer() {
    const container = this.canvasElement.nativeElement;
    this.width = container.clientWidth;
    this.height = container.clientHeight;

    this.svg = d3.select(this.svgElement.nativeElement)
      .attr('width', this.width)
      .attr('height', this.height);

    // 初始化 D3 力導向圖
    this.simulation = d3.forceSimulation()
      .force('link', d3.forceLink().id((d: any) => d.id).distance(100))
      .force('charge', d3.forceManyBody().strength(-300))
      .force('center', d3.forceCenter(this.width / 2, this.height / 2))
      .force('collision', d3.forceCollide().radius(50));

    // 創建縮放行為
    const zoom = d3.zoom()
      .scaleExtent([0.1, 4])
      .on('zoom', (event) => {
        this.svg.select('g').attr('transform', event.transform);
      });

    this.svg.call(zoom);
    
    // 添加主容器組
    this.svg.append('g')
      .attr('class', 'network-container');
  }

  private async loadData() {
    this.isLoading = true;
    try {
      // 獲取網絡數據
      const [routers, services, identities] = await Promise.all([
        this.zitiService.get('edge-routers'),
        this.zitiService.get('services'),
        this.zitiService.get('identities')
      ]);

      // 處理節點數據
      this.nodes = [
        ...routers.data.map(r => ({ ...r, type: 'router' })),
        ...services.data.map(s => ({ ...s, type: 'service' })),
        ...identities.data.map(i => ({ ...i, type: 'identity' }))
      ];

      // 處理連線數據
      this.links = this.generateLinks();

      this.updateVisualization();
    } catch (error) {
      console.error('Error loading network data:', error);
    } finally {
      this.isLoading = false;
    }
  }

  private generateLinks() {
    // 這裡根據實際業務邏輯生成連線
    // 示例：連接服務和路由器
    const links = [];
    // TODO: 實現實際的連線邏輯
    return links;
  }

  private updateVisualization() {
    const container = this.svg.select('.network-container');

    // 更新連線
    const link = container.selectAll('.link')
      .data(this.links)
      .join('line')
      .attr('class', 'link')
      .style('stroke', '#4a4a4a')
      .style('stroke-width', 2);

    // 更新節點
    const node = container.selectAll('.node')
      .data(this.nodes)
      .join('g')
      .attr('class', 'node')
      .call(d3.drag()
        .on('start', this.dragstarted.bind(this))
        .on('drag', this.dragged.bind(this))
        .on('end', this.dragended.bind(this)));

    // 添加節點圖標
    node.append('circle')
      .attr('r', 20)
      .attr('class', d => `node-${d.type}`)
      .style('fill', d => this.getNodeColor(d.type));

    // 添加節點標籤
    node.append('text')
      .attr('dy', 30)
      .attr('text-anchor', 'middle')
      .text(d => d.name)
      .style('fill', '#e0e0e0')
      .style('font-size', '12px');

    // 更新力導向圖
    this.simulation
      .nodes(this.nodes)
      .on('tick', () => {
        link
          .attr('x1', d => d.source.x)
          .attr('y1', d => d.source.y)
          .attr('x2', d => d.target.x)
          .attr('y2', d => d.target.y);

        node
          .attr('transform', d => `translate(${d.x},${d.y})`);
      });

    this.simulation.force('link').links(this.links);
  }

  private getNodeColor(type: string): string {
    const colors = {
      router: '#08dc5a',
      service: '#4a90e2',
      identity: '#f5a623'
    };
    return colors[type] || '#808080';
  }

  private dragstarted(event: any, d: any) {
    if (!event.active) this.simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
  }

  private dragged(event: any, d: any) {
    d.fx = event.x;
    d.fy = event.y;
  }

  private dragended(event: any, d: any) {
    if (!event.active) this.simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  }

  refreshData() {
    this.loadData();
  }

  toggleFullscreen() {
    this.isFullscreen = !this.isFullscreen;
    if (this.isFullscreen) {
      const container = this.canvasElement.nativeElement;
      this.width = window.innerWidth;
      this.height = window.innerHeight;
    } else {
      const container = this.canvasElement.nativeElement;
      this.width = container.clientWidth;
      this.height = container.clientHeight;
    }
    this.svg
      .attr('width', this.width)
      .attr('height', this.height);
    this.updateVisualization();
  }

  filterNodes() {
    // 實現節點過濾邏輯
    const filteredNodes = this.nodes.filter(node => 
      node.name.toLowerCase().includes(this.searchText.toLowerCase())
    );
    // 更新視覺化
    this.updateVisualization();
  }
} 