const DEFAULT_MARKER_SIZE: number = 20; // 默认滑块宽高
const TRACK_HEIGHT: number = 2;

export interface SliderTrackStyle {
  height?: number;
  backgroundColor?: ResourceColor;
  linearGradient?: LinearGradient;
}

@ComponentV2
export struct DefaultThumb {
  @Param color: ResourceColor = Color.White;
  @Param thumbSize: number = DEFAULT_MARKER_SIZE;

  build() {
    Column()
      .width(this.thumbSize)
      .height(this.thumbSize)
      .borderRadius(this.thumbSize / 2)
      .backgroundColor(this.color)
      .shadow({ radius: 4, color: 'rgba(0,0,0,0.15)', offsetX: 2, offsetY: 2 })
  }
}

@ComponentV2
export struct CustomThumb {
  @Param color: ResourceColor = Color.White;
  @Param lineColor: ResourceColor = 'rgba(0,0,0,0.61)';
  @Param thumbSize: number = DEFAULT_MARKER_SIZE;

  build() {
    Row({ space: 2 }) {
      Rect().width(2).height(8).radius(1).fill(this.lineColor)
      Rect().width(2).height(8).radius(1).fill(this.lineColor)
      Rect().width(2).height(8).radius(1).fill(this.lineColor)
    }
    .width(this.thumbSize)
    .height(this.thumbSize)
    .borderRadius(this.thumbSize / 2)
    .backgroundColor(this.color)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.15)', offsetX: 2, offsetY: 2 })
  }
}

enum MarkerType {
  LEFT = 0,
  RIGHT = 1
}

/**
 * @description 双向范围滑块，支持 allowRange 允许的滑动范围限制
 */
@ComponentV2
export struct RangeSlider {
  @Param max: number = 100;
  @Param min: number = 0;
  @Param values: [number, number] = [0, 100];
  @Param step: number = 1;
  @Param minDistance: number = 0;
  @Param trackStyle: SliderTrackStyle = {};
  @Param trackHighlightStyle: SliderTrackStyle = {};
  // 是否与滑块对齐
  @Param isAlignment: boolean = true;
  // 是否禁止滑动
  @Param disable: boolean = false;
  // 允许滑动的范围
  @Param allowRange?: SlideRange = undefined;
  @Param thumbSize: number = DEFAULT_MARKER_SIZE;

  @BuilderParam thumbLeft?: () => void;
  @BuilderParam thumbRight?: () => void;

  @Event onValuesChange?: (values: [number, number]) => void;
  @Event onValuesChangeFinish?: (values: [number, number]) => void;

  @Local private containerWidth: number = 0;
  @Local private containerHeight: number = 0;
  @Local private leftValue: number = 0;
  @Local private rightValue: number = 100;
  @Local private activeMarker: MarkerType = MarkerType.LEFT;
  @Local private isDragging: boolean = false;

  private dragStartLeftValue: number = 0;
  private dragStartRightValue: number = 0;

  private baseOffset: number = 0;
  private initialized: boolean = false;

  aboutToAppear(): void {
    this.initValues();
    this.initialized = true;
  }

  @Monitor('values')
  onValuesChanged(): void {
    if (!this.isDragging) {
      this.initValues();
    }
  }

  @Monitor('min', 'max', 'step', 'minDistance', 'allowRange')
  onRangeChanged(): void {
    if (this.initialized && !this.isDragging) {
      this.initValues();
    }
  }

  /**
   * 获取当前允许的绝对最小边界
   */
  @Computed
  private get effectiveMin(): number {
    if (this.allowRange && this.allowRange.from !== undefined) {
      return Math.max(this.min, this.allowRange.from);
    }
    return this.min;
  }

  /**
   * 获取当前允许的绝对最大边界
   */
  @Computed
  private get effectiveMax(): number {
    if (this.allowRange && this.allowRange.to !== undefined) {
      return Math.min(this.max, this.allowRange.to);
    }
    return this.max;
  }

  private initValues(): void {
    if (this.effectiveMax < this.effectiveMin) {
      this.leftValue = this.effectiveMin;
      this.rightValue = this.effectiveMin;
      return;
    }

    const first = Math.max(this.effectiveMin, Math.min(this.effectiveMax, this.values[0]));
    const second = Math.max(this.effectiveMin, Math.min(this.effectiveMax, this.values[1]));

    let lVal = Math.min(first, second);
    let rVal = Math.max(first, second);

    // 间距校验
    if (rVal - lVal < this.actualMinDistance) {
      rVal = Math.min(this.effectiveMax, lVal + this.actualMinDistance);
      lVal = Math.max(this.effectiveMin, rVal - this.actualMinDistance);
    }

    this.leftValue = lVal;
    this.rightValue = rVal;
  }

  // 滑块容器高度：取左右滑块尺寸的最大值
  private get markerSize(): number {
    return Math.max(DEFAULT_MARKER_SIZE, this.containerHeight);
  }

  // 可用轨道宽度
  private get usableWidth(): number {
    return Math.max(0, this.containerWidth - (this.isAlignment ? 0 : this.markerSize));
  }

  @Computed
  private get range(): number {
    return Math.max(0, this.max - this.min);
  }

  private get leftCenterX(): number {
    return this.valueToPosition(this.leftValue);
  }

  private get rightCenterX(): number {
    return this.valueToPosition(this.rightValue);
  }

  private valueToPosition(value: number): number {
    if (this.usableWidth <= 0 || this.range <= 0) {
      return 0;
    }
    return ((value - this.min) / this.range) * (this.isAlignment ? this.usableWidth - this.markerSize : this.usableWidth);
  }

  private normalizeStep(value: number): number {
    const actualStep = this.step > 0 ? this.step : 1;
    const result = this.min + Math.round((value - this.min) / actualStep) * actualStep;
    return Math.max(this.effectiveMin, Math.min(this.effectiveMax, Number(result.toFixed(8))));
  }

  @Computed
  private get actualMinDistance(): number {
    return Math.max(0, Math.min(this.range, this.minDistance));
  }

  private handleDragUpdate(offsetX: number): void {
    if (this.usableWidth <= 0 || this.disable) return;

    const deltaX = offsetX - this.baseOffset;
    const deltaValue = (deltaX / this.usableWidth) * this.range;
    const minDistance = this.actualMinDistance;

    if (this.activeMarker === MarkerType.LEFT) {
      const candidate = this.dragStartLeftValue + deltaValue;
      const value = this.normalizeStep(candidate);

      if (value <= this.rightValue - minDistance) {
        this.leftValue = Math.max(this.effectiveMin, value);
      } else if (minDistance === 0 && value > this.rightValue) {
        this.leftValue = this.rightValue;
        this.rightValue = Math.min(this.effectiveMax, value);
        this.activeMarker = MarkerType.RIGHT;
        this.baseOffset = offsetX;
        this.dragStartRightValue = this.rightValue;
      } else {
        this.leftValue = Math.min(value, this.rightValue - minDistance);
      }
    } else {
      const candidate = this.dragStartRightValue + deltaValue;
      const value = this.normalizeStep(candidate);

      if (value >= this.leftValue + minDistance) {
        this.rightValue = Math.min(this.effectiveMax, value);
      } else if (minDistance === 0 && value < this.leftValue) {
        this.rightValue = this.leftValue;
        this.leftValue = Math.max(this.effectiveMin, value);
        this.activeMarker = MarkerType.LEFT;
        this.baseOffset = offsetX;
        this.dragStartLeftValue = this.leftValue;
      } else {
        this.rightValue = Math.max(value, this.leftValue + minDistance);
      }
    }

    this.emitChange();
  }

  private finishDrag(): void {
    if (!this.isDragging || this.disable) {
      return;
    }
    this.isDragging = false;
    this.onValuesChangeFinish?.([this.leftValue, this.rightValue]);
  }

  private emitChange(): void {
    this.onValuesChange?.([this.leftValue, this.rightValue]);
  }

  @Computed
  private get trackHeight(): number {
    if (this.trackStyle?.height) {
      const height = parseFloat(String(this.trackStyle?.height));
      if (!Number.isNaN(height)) {
        return Number(height);
      }
    }
    return TRACK_HEIGHT;
  }

  @Computed
  private get trackHighlightHeight(): number {
    if (this.trackHighlightStyle?.height) {
      const height = parseFloat(String(this.trackHighlightStyle?.height));
      if (!Number.isNaN(height)) {
        return Number(height);
      }
    }
    return TRACK_HEIGHT;
  }

  @Builder
  private buildMarker(isLeft: boolean) {
    if (isLeft) {
      if (this.thumbLeft) {
        this.thumbLeft();
      } else {
        DefaultThumb({ thumbSize: this.thumbSize });
      }
    } else {
      if (this.thumbRight) {
        this.thumbRight();
      } else {
        DefaultThumb({ thumbSize: this.thumbSize });
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 底层轨道
      Row()
        .width(this.usableWidth)
        .height(this.trackHeight)
        .linearGradient(this.trackStyle?.linearGradient ?? {
          colors: [
            [this.trackStyle?.backgroundColor ?? '#999999', 0],
            [this.trackStyle?.backgroundColor ?? '#999999', 1]
          ]
        })
        .borderRadius(this.trackHeight * 0.5)
        .translate({
          x: this.isAlignment ? 0 : this.markerSize / 2,
          y: (this.markerSize - this.trackHeight) / 2
        })

      // 2. 高亮区间轨道
      Row()
        .width(Math.max(0, this.rightCenterX - this.leftCenterX))
        .height(this.trackHighlightHeight)
        .linearGradient(this.trackHighlightStyle?.linearGradient ?? {
          colors: [
            [this.trackHighlightStyle?.backgroundColor ?? Color.Blue, 0],
            [this.trackHighlightStyle?.backgroundColor ?? Color.Blue, 1]
          ]
        })
        .borderRadius(this.trackHighlightHeight * 0.5)
        .translate({
          x: this.markerSize / 2 + this.leftCenterX,
          y: (this.markerSize - this.trackHighlightHeight) / 2
        })

      // 3. 左滑块
      Column() {
        this.buildMarker(true)
      }
      .translate({
        x: this.leftCenterX,
      })
      .zIndex(this.activeMarker === MarkerType.LEFT ? 2 : 1)
      .enabled(!this.disable)
      .opacity(this.disable ? 0.6 : 1)
      .responseRegion({
        x: -10,
        y: -10,
        width: this.thumbSize + 20,
        height: this.thumbSize + 20
      })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionStart((event: GestureEvent) => {
            if (this.disable) return;
            this.isDragging = true;
            this.activeMarker = MarkerType.LEFT;
            this.dragStartLeftValue = this.leftValue;
            this.dragStartRightValue = this.rightValue;
            this.baseOffset = 0;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.handleDragUpdate(event.offsetX);
          })
          .onActionEnd(() => {
            this.finishDrag();
          })
      )

      // 4. 右滑块
      Column() {
        this.buildMarker(false)
      }
      .translate({
        x: this.rightCenterX,
      })
      .zIndex(this.activeMarker === MarkerType.RIGHT ? 2 : 1)
      .enabled(!this.disable)
      .opacity(this.disable ? 0.6 : 1)
      .responseRegion({
        x: -10,
        y: -10,
        width: this.thumbSize + 20,
        height: this.thumbSize + 20
      })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal })
          .onActionStart((event: GestureEvent) => {
            if (this.disable) return;
            this.isDragging = true;
            this.activeMarker = MarkerType.RIGHT;
            this.dragStartLeftValue = this.leftValue;
            this.dragStartRightValue = this.rightValue;
            this.baseOffset = 0;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.handleDragUpdate(event.offsetX);
          })
          .onActionEnd(() => {
            this.finishDrag();
          })
      )
    }
    .width('100%')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.containerWidth = Number(newValue.width);
      this.containerHeight = Number(newValue.height);
    })
  }
}