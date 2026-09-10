import { FlatTable } from '@flat/flat_table';
import { RouteItem } from '../models/NomalModel';

@Builder
export function FlatTableDemoBuilder() {
  FlatTableDemo();
}

@Entry
@ComponentV2
struct FlatTableDemo {
  pathStack: NavPathStack = new NavPathStack();
  @Local title: string = 'Demo';

  aboutToAppear() {
    // query navigation info
    let navigationInfo: NavigationInfo = this.queryNavigationInfo() as NavigationInfo;
    if (navigationInfo !== undefined) {
      this.pathStack = navigationInfo.pathStack;
    }
    const info = this.queryNavDestinationInfo();
    if (info && info.param) {
      console.log('获取到路由参数: ' + JSON.stringify(info.param));
      const param = info.param as RouteItem;
      if(param.title) {
        this.title = param.title;
      }
    }
  }

  build() {
    NavDestination() {
      FlatTable()
    }
    .title(this.title)
  }
}