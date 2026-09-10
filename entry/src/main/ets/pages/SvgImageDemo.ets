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
      SVGImage({source: $rawfile('svg_clock.svg'), bounds: 80})
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
