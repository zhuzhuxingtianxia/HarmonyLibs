import { CustomThumb, DefaultThumb, RangeSlider } from "@flat/range_slider";

@Builder
export function RangeSliderDemoBuilder() {
  RangeSliderDemo();
}

@Entry
@ComponentV2
struct RangeSliderDemo {
  pathStack: NavPathStack = new NavPathStack();

  @Local values1: [number,number] = [10,90];
  @Local values2: [number,number] = [0,100];
  @Local values3: [number,number] = [10,80];

  @LocalBuilder
  customThumbBuilder(isLeft: boolean) {
    if(isLeft) {
      CustomThumb()
    }else{
      CustomThumb({
        color: Color.Orange,
        lineColor: Color.White
      })
    }
  }

  @LocalBuilder
  customThumbBuilder1(isLeft: boolean) {
    if(isLeft) {
      Column(){
        Text(`${this.values3[0]}`).fontSize(12)
      }
      .justifyContent(FlexAlign.Center)
      .width(30)
      .height(30)
      .backgroundColor(Color.Pink)
    }else{
      Column(){
        Text(`${this.values3[1]}`).fontSize(12)
      }
      .justifyContent(FlexAlign.Center)
      .width(30)
      .height(30)
      .backgroundColor(Color.Pink)
    }
  }

  @LocalBuilder
  customThumbBuilder2() {
    Column(){
      Polygon()
        .width(20)
        .height(20)
        .points([[10, 0], [20, 20], [0, 20]])
        .fill(Color.Blue)
        .translate({y: 10})
    }
  }

  build() {
    NavDestination(){
      Scroll(){
        Column({space: 30}){
          // 默认
          RangeSlider()
          Column(){
            Text(`${this.values1[0]}-${this.values1[1]}`)
            // 设置最大最小值
            Row({space: 5}){
              Text('10')
              RangeSlider({
                max: 90,
                min: 10,
                thumbSize: 40,
                onValuesChange:(values: [number,number])=>{
                  this.values1 = values;
                }
              })
                .layoutWeight(1)
              Text('90')
            }
          }

          Column(){
            Text(`${this.values2[0]}-${this.values2[1]}`)
            RangeSlider({
              isAlignment: false,
              trackStyle: {
                height: 4,
                backgroundColor: Color.Black
              },
              trackHighlightStyle: {
                height: 5,
                linearGradient: {
                  direction:GradientDirection.Right,
                  colors: [
                    [Color.Green, 0],
                    [Color.Red, 1],
                  ]
                }
              },
              onValuesChange:(values: [number,number])=>{
                this.values2 = values;
              }
            })
          }
          RangeSlider({
            trackStyle: {
              height: 20,
            },
            trackHighlightStyle: {
              height: 20,
              linearGradient: {
                direction:GradientDirection.Right,
                colors: [
                  [Color.Green, 0],
                  [Color.Red, 1],
                ]
              }
            },
          })

          // 自定义滑块
          RangeSlider({
            trackHighlightStyle: {
              height: 3,
              linearGradient: {
                direction:GradientDirection.Right,
                colors: [
                  [Color.Green, 0],
                  [Color.Red, 1],
                ]
              }
            },
            thumbLeft: ()=>{this.customThumbBuilder(true)},
            thumbRight: ()=>{this.customThumbBuilder(false)},
          })
          // 自定义滑块 + 值显示
          RangeSlider({
            values: this.values3,
            thumbLeft: ()=>{this.customThumbBuilder1(true)},
            thumbRight: ()=>{this.customThumbBuilder1(false)},
            onValuesChange:(values: [number,number])=>{
              this.values3 = values;
            }
          })

          // 自定义三角滑块
          RangeSlider({
            isAlignment: false,
            thumbLeft: ()=>{this.customThumbBuilder2()},
            thumbRight: ()=>{this.customThumbBuilder2()},
          })

        }
        .padding(20)
        .width('100%')
      }
      .width('100%')
      .align(Alignment.TopStart)
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, {alwaysEnabled: true})
    }
    .title('RangeSlider')
    .backgroundColor('#F5F5F5')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }
}