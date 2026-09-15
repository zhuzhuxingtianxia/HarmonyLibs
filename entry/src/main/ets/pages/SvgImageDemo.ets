import { SVGImage } from "@flat/svg_image";
import { RouteItem } from "../models/NomalModel";
import { LengthMetrics } from "@kit.ArkUI";

@Builder
export function SvgImageDemoBuilder() {
  SvgImageDemo();
}

@Entry
@ComponentV2
struct SvgImageDemo {
  pathStack: NavPathStack = new NavPathStack();
  @Local title: string = 'Demo';

  build() {
    NavDestination(){
      Scroll(){
        Column({space: 20}){
          Row({space: 10}) {
            SVGImage({source: $rawfile('visitor_icon.svg')})
              .backgroundColor(Color.Black)

            SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 30, stroke: '#000000'})

            SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 60, stroke: '#f00000'})

            SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 60, colorSwap: {'#FFFFFF': '#00FF00'}})
          }
          Row({space: 10}) {
            SVGImage({source: $rawfile('fill_svg.svg')})
            SVGImage({source: $rawfile('fill_svg.svg'), bounds: 80})
          }
          Row({space: 10}) {
            SVGImage({source: $rawfile('svg_clock.svg'), bounds: 80})
            SVGImage({source: $rawfile('svg_clock.svg'), bounds: 80,
              idStyles: {
                "Bg": { fill: '#F97316'}
              },
              colorSwap: {"#FFC50D": "#FF0000", '#333333': '#0000FF'}
            })
          }

          Flex({
            direction: FlexDirection.Row,wrap: FlexWrap.Wrap,
            space: {main: LengthMetrics.vp(10), cross: LengthMetrics.vp(20)}
          }) {
            SVGImage({source: $rawfile('7doodle.svg'), bounds: 100})
            SVGImage({source: $rawfile('box.svg'), bounds: 100})
            SVGImage({source: $rawfile('gradient_test.svg'), bounds: 100})
            SVGImage({source: $rawfile('ic_launcher_round.svg'), bounds: 100})
            SVGImage({source: $rawfile('lego.svg'), bounds: 300})
            SVGImage({source: $rawfile('line.svg'), bounds: 100})
            SVGImage({source: $rawfile('mask_all_props.svg'), bounds: 100})
            SVGImage({source: $rawfile('mask_common_props.svg'), bounds: 100})
            SVGImage({source: $rawfile('mask_own_props.svg'), bounds: 100})
            SVGImage({source: $rawfile('mask_test.svg'), bounds: 100})
            SVGImage({source: $rawfile('noto_emoji_u1f490.svg'), bounds: 100})
            SVGImage({source: $rawfile('oranges.svg'), bounds: 100})
            SVGImage({source: $rawfile('peach.svg'), bounds: 100})
            SVGImage({source: $rawfile('polygon.svg'), bounds: 100})
            SVGImage({source: $rawfile('rubiks-cube.svg'), bounds: 100})
          }

          Row({space: 10}) {
            SVGImage({source: $rawfile('mic-animated.svg'), bounds: 80})
          }
          Row({space: 10}) {
            SVGImage({source: $rawfile('svg_animate.svg'), bounds: 80})
          }
        }
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, {alwaysEnabled: true})

    }
    .title(this.title)
    .onReady((context: NavDestinationContext) => {
      const param = context.pathInfo.param as RouteItem;
      if(param.title) {
        this.title = param.title;
      }
      this.pathStack = context.pathStack;
    })
  }
}
