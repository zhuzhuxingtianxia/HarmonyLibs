import { SVGImage } from "@flat/svg_image";
import { RouteItem } from "../models/NomalModel";

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
      Column({space: 20}){
        Row({space: 10}) {
          SVGImage({source: $rawfile('visitor_icon.svg')})
            .backgroundColor(Color.Black)

          SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 30, stroke: '#000000'})

          SVGImage({source: $rawfile('visitor_icon.svg'), bounds: 60, stroke: '#f00000'})
        }
        Row({space: 10}) {
          SVGImage({source: $rawfile('svg_clock.svg'), bounds: 80})
        }
        Row({space: 10}) {
          SVGImage({source: $rawfile('mic-animated.svg'), bounds: 80})
        }
        Row({space: 10}) {
          SVGImage({source: $rawfile('svg_animate.svg'), bounds: 80})
        }
      }

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
