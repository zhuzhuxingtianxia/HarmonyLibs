import { RouteItem } from '../models/NomalModel';
import { JSON } from '@kit.ArkTS';

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack();

  dataSource: RouteItem[] = [
    {title: 'SvgImage', routeName: 'SvgImageDemo'},
    {title: 'FlatTable', routeName: 'FlatTableDemo'},
  ];

  build() {
    Navigation(this.pathStack){
      List(){
        ForEach(this.dataSource,(item: RouteItem,index)=>{
          ListItem(){
            Column(){
              Text(item.title).padding({top: 15, bottom: 15})
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .onClick(()=>{
              this.pathStack.pushPathByName(item.routeName, item);
              // 或
              // this.pathStack.pushPath({name: item.routeName, param: item});
            })
          }
        },(item: RouteItem,index)=>JSON.stringify(item))
      }
      .padding({left: 15, right: 15})
      .divider({ strokeWidth: 0.5, color: '#40000000' })
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, {alwaysEnabled: true})

    }
    .title('Navigation')
    .titleMode(NavigationTitleMode.Mini)
    .hideBackButton(true)

  }
}