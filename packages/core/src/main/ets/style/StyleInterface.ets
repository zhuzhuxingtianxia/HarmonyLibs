export interface ViewStyle {
  width?: Length,
  height?: Length,
  opacity?: number,
  // FlexEModifier不支持 该属性，需单独处理
  justifyContent?: FlexAlign,
  // Column-HorizontalAlign Row-VerticalAlign FlexEModifier不支持
  alignItems?: VerticalAlign|HorizontalAlign,
  backgroundColor?: ResourceColor,
  margin?: Margin | Length,
  padding?: Padding | Length,
  flex?: number | string,
  space?: number;
  border?: BorderOptions;
  borderRadius?: Length | BorderRadiuses | LocalizedBorderRadiuses;
  clip?: boolean;
  shadow?: ShadowOptions;
}

// 防止与TextStyle 命名冲突
export interface TextEStyle extends ViewStyle {
  color?: ResourceColor,
  fontSize?: number | string | Resource,
  fontWeight?: number | FontWeight | string,
  fontFamily?: string | Resource,
  lineHeight?: number | string | Resource,
  wordBreak?: WordBreak,
  textAlign?: TextAlign,
  // 划线
  decoration?: DecorationStyleInterface,
  maxLines?:number,
  textOverflow?: TextOverflowOptions,
}