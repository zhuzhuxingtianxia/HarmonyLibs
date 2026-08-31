import { ViewStyle } from '@flat/core';
import { FlatTable } from '@flat/flat_table';

@Entry
@ComponentV2
struct Index {
  @Local message: string = 'Hello World';
  @Local style: ViewStyle = {};

  build() {
    RelativeContainer() {
      FlatTable()
      Text(this.message)
        .id('HelloWorld')
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .alignRules({
          center: { anchor: '__container__', align: VerticalAlign.Center },
          middle: { anchor: '__container__', align: HorizontalAlign.Center }
        })
        .onClick(() => {
          this.message = 'Welcome';
        })
    }
    .height('100%')
    .width('100%')
  }
}