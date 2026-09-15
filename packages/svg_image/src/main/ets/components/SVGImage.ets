import { convertxml, buffer, JSON } from "@kit.ArkTS";
import { Point } from "@kit.TestKit";

interface SvgItemData {
  id: string;
  commands: string;
  fill: ResourceColor;
  stroke: ResourceColor;
  strokeWidth: number;
  strokeLineCap?: LineCapStyle;
  strokeLineJoin?: LineJoinStyle;
  opacity?: number;
}

interface SvgInheritedStyle {
  fill?: string;
  stroke?: string;
  strokeWidth?: string;
  strokeLineCap?: string;
  strokeLineJoin?: string;
  opacity?: string;
  transform?: SvgTransform;
}

interface SvgTransform {
  a: number;
  b: number;
  c: number;
  d: number;
  tx: number;
  ty: number;
  sx: number;
  sy: number;
}

/**
 * @description 加载svg类型图片通用组件
 * 1. 支持$rawfile加载的资源
 * 2. 支持$r加载的本地字符串资源
 * 3. 支持svg字符串
 * 4. (暂不支持)按功能角色（Role）、原颜色替换（Color Swap）或 图层ID（Layer ID）进行分色控制
 * 5. (暂不支持)svg中的动画效果
 * 6. 使用convertxml解析svg的xml
 * 7. 将解析后的数据使用Shape及其子组件渲染成鸿蒙组件
 * */
@ComponentV2
export struct SVGImage {
  @Param @Require source: ResourceStr;
  @Param bounds?: number = undefined;
  @Param fill?: ResourceColor = undefined;
  @Param stroke?: ResourceColor = undefined;
  @Param strokeWidth?: number = undefined;

  @Local private items: SvgItemData[] = [];
  @Local private viewBoxX: number = 0;
  @Local private viewBoxY: number = 0;
  @Local private viewBoxWidth: number = 24;
  @Local private viewBoxHeight: number = 24;
  @Local private svgWidth: number = 0;
  @Local private svgHeight: number = 0;

  @Monitor('source', 'fill', 'stroke', 'strokeWidth')
  onPropsChanged(): void {
    this.parseSvg();
  }

  aboutToAppear(): void {
    this.parseSvg();
  }

  private get renderWidth(): Length {
    if (this.bounds !== undefined && this.bounds > 0) {
      return this.bounds;
    }
    if (this.svgWidth > 0) {
      return this.svgWidth;
    }
    return this.viewBoxWidth > 0 ? this.viewBoxWidth : 24;
  }

  private get renderHeight(): Length {
    if (this.bounds !== undefined && this.bounds > 0) {
      return this.bounds;
    }
    if (this.svgHeight > 0) {
      return this.svgHeight;
    }
    return this.viewBoxHeight > 0 ? this.viewBoxHeight : 24;
  }

  private loadSvgContent(): string {
    if (!this.source) {
      return '';
    }

    if (typeof this.source === 'string') {
      const trimmed = this.source.trim();
      if (trimmed.startsWith('<') || trimmed.includes('<svg')) {
        return this.source;
      }
      try {
        const rawBytes = getContext(this).resourceManager.getRawFileContentSync(this.source);
        if (rawBytes && rawBytes.length > 0) {
          return buffer.from(rawBytes).toString('utf-8');
        }
      } catch (error) {
        console.log('loadSvgContent error:', JSON.stringify(error));
      }
      return this.source;
    }

    if (typeof this.source === 'object') {
      const res = this.source as Resource;
      // 1. 尝试通过 $rawfile 加载 (res.type == 30000 或 res.params[0] 路径)
      if (Array.isArray(res.params) && typeof res.params[0] === 'string' && res.params[0].length > 0) {
        try {
          const rawBytes = getContext(this).resourceManager.getRawFileContentSync(res.params[0]);
          if (rawBytes && rawBytes.length > 0) {
            return buffer.from(rawBytes).toString('utf-8');
          }
        } catch (error) {
          console.log('getRawFileContentSync error:', JSON.stringify(error));
        }
      }
      // 2. 尝试通过 $r 本地字符串资源加载
      try {
        const str = getContext(this).resourceManager.getStringSync(res);
        if (str && (str.includes('<svg') || str.trim().startsWith('<'))) {
          return str;
        }
      } catch (error) {
        console.log('getStringSync error:', JSON.stringify(error));
      }
      // 3. 尝试通过 $r 媒体资源加载
      try {
        const mediaBytes = getContext(this).resourceManager.getMediaContentSync(res);
        if (mediaBytes && mediaBytes.length > 0) {
          return buffer.from(mediaBytes).toString('utf-8');
        }
      } catch (error) {
        console.log('getMediaContentSync error:', JSON.stringify(error));
      }
    }
    return '';
  }

  private parseSvg(): void {
    try {
      const svgText = this.loadSvgContent();
      if (!svgText || !svgText.trim()) {
        this.items = [];
        return;
      }

      const conv = new convertxml.ConvertXML();
      const options: convertxml.ConvertOptions = {
        trim: true,
        ignoreDeclaration: true,
        ignoreInstruction: true,
        ignoreComment: true,
        ignoreCDATA: false,
        ignoreDoctype: true,
        declarationKey: '_declaration',
        instructionKey: '_instruction',
        attributesKey: '_attributes',
        textKey: '_text',
        cdataKey: '_cdata',
        doctypeKey: '_doctype',
        commentKey: '_comment',
        parentKey: '_parent',
        typeKey: '_type',
        nameKey: '_name',
        elementsKey: '_elements'
      };

      const resultObj = conv.convertToJSObject(svgText, options) as Record<string, Object>;
      if (!resultObj) {
        this.items = [];
        return;
      }

      const svgNode = this.findSvgNode(resultObj);
      if (!svgNode) {
        this.items = [];
        return;
      }

      const svgAttrs = this.getNodeAttributes(svgNode);

      // 解析 viewBox 属性
      let vbParsed = false;
      const vbStr = svgAttrs['viewBox'] ?? svgAttrs['viewbox'];
      if (vbStr) {
        const parts = vbStr.trim().split(/[\s,]+/).map((v: string) => parseFloat(v));
        if (parts.length === 4 && !parts.some((n: number) => isNaN(n))) {
          this.viewBoxX = parts[0];
          this.viewBoxY = parts[1];
          this.viewBoxWidth = parts[2];
          this.viewBoxHeight = parts[3];
          vbParsed = true;
        }
      }

      // 解析 svg 宽高属性
      const w = parseFloat(svgAttrs['width'] ?? '');
      const h = parseFloat(svgAttrs['height'] ?? '');
      this.svgWidth = isNaN(w) ? 0 : w;
      this.svgHeight = isNaN(h) ? 0 : h;

      if (!vbParsed) {
        this.viewBoxX = 0;
        this.viewBoxY = 0;
        this.viewBoxWidth = this.svgWidth > 0 ? this.svgWidth : 24;
        this.viewBoxHeight = this.svgHeight > 0 ? this.svgHeight : 24;
      }

      // 提取所有矢量子节点
      const collected: SvgItemData[] = [];
      const inheritedStyle: SvgInheritedStyle = {
        fill: svgAttrs['fill'],
        stroke: svgAttrs['stroke'],
        strokeWidth: svgAttrs['stroke-width'] ?? svgAttrs['strokeWidth'],
        strokeLineCap: svgAttrs['stroke-linecap'] ?? svgAttrs['strokeLinecap'],
        strokeLineJoin: svgAttrs['stroke-linejoin'] ?? svgAttrs['strokeLinejoin'],
        opacity: svgAttrs['opacity'],
        transform: { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0, sx: 1, sy: 1 },
      };

      this.traverseNodes(svgNode, inheritedStyle, collected);
      this.items = collected;
    } catch (_) {
      this.items = [];
    }
  }

  private findSvgNode(node: Record<string, Object>): Record<string, Object> | null {
    if (this.getNodeName(node) === 'svg') {
      return node;
    }
    const children = this.getNodeChildren(node);
    for (const child of children) {
      const found = this.findSvgNode(child);
      if (found) {
        return found;
      }
    }
    return null;
  }

  private getNodeName(node: Record<string, Object>): string {
    const name = (node['_name'] ?? node['name']) as string | undefined;
    return (name ?? '').toLowerCase();
  }

  private getNodeAttributes(node: Record<string, Object>): Record<string, string> {
    const rawAttrs = (node['_attributes'] ?? node['attributes']) as Record<string, string> | undefined;
    const result: Record<string, string> = {};
    if (rawAttrs && typeof rawAttrs === 'object') {
      for (const k of Object.keys(rawAttrs)) {
        result[k] = String(rawAttrs[k]);
      }
    }
    if (result['style']) {
      const styleObj = this.parseStyleAttr(result['style']);
      for (const sk of Object.keys(styleObj)) {
        if (!result[sk]) {
          result[sk] = styleObj[sk];
        }
      }
    }
    return result;
  }

  private getNodeChildren(node: Record<string, Object>): Array<Record<string, Object>> {
    const children = (node['_elements'] ?? node['elements']) as Array<Record<string, Object>> | undefined;
    return Array.isArray(children) ? children : [];
  }

  private parseStyleAttr(styleStr?: string): Record<string, string> {
    const result: Record<string, string> = {};
    if (!styleStr) return result;
    const parts = styleStr.split(';');
    for (const part of parts) {
      const idx = part.indexOf(':');
      if (idx > 0) {
        const k = part.substring(0, idx).trim().toLowerCase();
        const v = part.substring(idx + 1).trim();
        if (k && v) {
          result[k] = v;
        }
      }
    }
    return result;
  }

  private multiplyMatrix(m1: SvgTransform, m2: SvgTransform): SvgTransform {
    const a = m1.a * m2.a + m1.c * m2.b;
    const b = m1.b * m2.a + m1.d * m2.b;
    const c = m1.a * m2.c + m1.c * m2.d;
    const d = m1.b * m2.c + m1.d * m2.d;
    const tx = m1.a * m2.tx + m1.c * m2.ty + m1.tx;
    const ty = m1.b * m2.tx + m1.d * m2.ty + m1.ty;
    return { a, b, c, d, tx, ty, sx: Math.hypot(a, b), sy: Math.hypot(c, d) };
  }

  private parseTransform(transformStr?: string): SvgTransform {
    let current: SvgTransform = { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0, sx: 1, sy: 1 };
    if (!transformStr) return current;

    const regex = /(matrix|translate|scale|rotate)\s*\(([^)]+)\)/g;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(transformStr)) !== null) {
      const type = match[1];
      const args = match[2].trim().split(/[\s,]+/).map((v: string) => parseFloat(v));
      let step: SvgTransform = { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0, sx: 1, sy: 1 };

      if (type === 'matrix' && args.length >= 6) {
        step = { a: args[0], b: args[1], c: args[2], d: args[3], tx: args[4], ty: args[5], sx: Math.hypot(args[0], args[1]), sy: Math.hypot(args[2], args[3]) };
      } else if (type === 'translate') {
        const tx = args[0] || 0;
        const ty = args[1] !== undefined ? args[1] : 0;
        step = { a: 1, b: 0, c: 0, d: 1, tx, ty, sx: 1, sy: 1 };
      } else if (type === 'scale') {
        const sx = args[0] !== undefined ? args[0] : 1;
        const sy = args[1] !== undefined ? args[1] : sx;
        step = { a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0, sx: Math.abs(sx), sy: Math.abs(sy) };
      } else if (type === 'rotate') {
        const rad = (args[0] || 0) * Math.PI / 180;
        const cos = Math.cos(rad); const sin = Math.sin(rad);
        if (args.length >= 3) {
          const cx = args[1]; const cy = args[2];
          const tx = cx - cx * cos + cy * sin;
          const ty = cy - cx * sin - cy * cos;
          step = { a: cos, b: sin, c: -sin, d: cos, tx, ty, sx: 1, sy: 1 };
        } else {
          step = { a: cos, b: sin, c: -sin, d: cos, tx: 0, ty: 0, sx: 1, sy: 1 };
        }
      }
      current = this.multiplyMatrix(current, step);
    }
    return current;
  }

  private applyPointTransform(x: number, y: number, transform: SvgTransform): Point {
    return {
      x: transform.a * x + transform.c * y + transform.tx,
      y: transform.b * x + transform.d * y + transform.ty
    };
  }

  private applyVectorTransform(x: number, y: number, transform: SvgTransform): Point {
    return {
      x: transform.a * x + transform.c * y,
      y: transform.b * x + transform.d * y
    };
  }

  // ★ 核心修复：追踪路径轨迹 cx、cy，彻底支持 H 和 V 转换为绝对 L（消除形变）
  private translatePath(d: string, transform: SvgTransform): string {
    if (!d) return '';
    if (transform.a === 1 && transform.b === 0 && transform.c === 0 && transform.d === 1 && transform.tx === 0 && transform.ty === 0) return d;

    const tokens = d.match(/[a-df-z]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?/gi);
    if (!tokens) return d;

    let result = '';
    let currentCmd = '';
    let i = 0;

    let cx = 0; let cy = 0;
    let startX = 0; let startY = 0;

    while (i < tokens.length) {
      let token = tokens[i];
      if (/^[a-df-z]$/i.test(token)) {
        currentCmd = token;
        i++;
        if (currentCmd === 'Z' || currentCmd === 'z') {
          cx = startX; cy = startY;
          result += ' Z';
          continue;
        }
        if (i >= tokens.length) break;
      }

      if (currentCmd === 'M' || currentCmd === 'L' || currentCmd === 'T') {
        const x = parseFloat(tokens[i]); const y = parseFloat(tokens[i + 1]);
        cx = x; cy = y;
        if (currentCmd === 'M') { startX = x; startY = y; }
        const p = this.applyPointTransform(x, y, transform);
        result += ` ${currentCmd} ${p.x} ${p.y}`;
        i += 2;
        if (currentCmd === 'M') currentCmd = 'L';
      }
      else if (currentCmd === 'm') {
        const x = parseFloat(tokens[i]); const y = parseFloat(tokens[i + 1]);
        cx += x; cy += y;
        startX = cx; startY = cy;
        if (result === '') {
          const p = this.applyPointTransform(cx, cy, transform);
          result += ` M ${p.x} ${p.y}`;
        } else {
          const v = this.applyVectorTransform(x, y, transform);
          result += ` m ${v.x} ${v.y}`;
        }
        i += 2;
        currentCmd = 'l';
      }
      else if (currentCmd === 'l' || currentCmd === 't') {
        const x = parseFloat(tokens[i]); const y = parseFloat(tokens[i + 1]);
        cx += x; cy += y;
        const v = this.applyVectorTransform(x, y, transform);
        result += ` ${currentCmd} ${v.x} ${v.y}`;
        i += 2;
      }
      else if (currentCmd === 'H') {
        const x = parseFloat(tokens[i]);
        cx = x;
        const p = this.applyPointTransform(cx, cy, transform);
        result += ` L ${p.x} ${p.y}`;
        i += 1;
      }
      else if (currentCmd === 'h') {
        const x = parseFloat(tokens[i]);
        cx += x;
        const v = this.applyVectorTransform(x, 0, transform);
        result += ` l ${v.x} ${v.y}`;
        i += 1;
      }
      else if (currentCmd === 'V') {
        const y = parseFloat(tokens[i]);
        cy = y;
        const p = this.applyPointTransform(cx, cy, transform);
        result += ` L ${p.x} ${p.y}`;
        i += 1;
      }
      else if (currentCmd === 'v') {
        const y = parseFloat(tokens[i]);
        cy += y;
        const v = this.applyVectorTransform(0, y, transform);
        result += ` l ${v.x} ${v.y}`;
        i += 1;
      }
      else if (currentCmd === 'C') {
        const x1 = parseFloat(tokens[i]); const y1 = parseFloat(tokens[i + 1]);
        const x2 = parseFloat(tokens[i + 2]); const y2 = parseFloat(tokens[i + 3]);
        const x = parseFloat(tokens[i + 4]); const y = parseFloat(tokens[i + 5]);
        cx = x; cy = y;
        const p1 = this.applyPointTransform(x1, y1, transform);
        const p2 = this.applyPointTransform(x2, y2, transform);
        const p = this.applyPointTransform(x, y, transform);
        result += ` C ${p1.x} ${p1.y} ${p2.x} ${p2.y} ${p.x} ${p.y}`;
        i += 6;
      }
      else if (currentCmd === 'c') {
        const dx1 = parseFloat(tokens[i]); const dy1 = parseFloat(tokens[i + 1]);
        const dx2 = parseFloat(tokens[i + 2]); const dy2 = parseFloat(tokens[i + 3]);
        const dx = parseFloat(tokens[i + 4]); const dy = parseFloat(tokens[i + 5]);
        cx += dx; cy += dy;
        const v1 = this.applyVectorTransform(dx1, dy1, transform);
        const v2 = this.applyVectorTransform(dx2, dy2, transform);
        const v = this.applyVectorTransform(dx, dy, transform);
        result += ` c ${v1.x} ${v1.y} ${v2.x} ${v2.y} ${v.x} ${v.y}`;
        i += 6;
      }
      else if (currentCmd === 'S' || currentCmd === 'Q') {
        const x1 = parseFloat(tokens[i]); const y1 = parseFloat(tokens[i + 1]);
        const x = parseFloat(tokens[i + 2]); const y = parseFloat(tokens[i + 3]);
        cx = x; cy = y;
        const p1 = this.applyPointTransform(x1, y1, transform);
        const p = this.applyPointTransform(x, y, transform);
        result += ` ${currentCmd} ${p1.x} ${p1.y} ${p.x} ${p.y}`;
        i += 4;
      }
      else if (currentCmd === 's' || currentCmd === 'q') {
        const dx1 = parseFloat(tokens[i]); const dy1 = parseFloat(tokens[i + 1]);
        const dx = parseFloat(tokens[i + 2]); const dy = parseFloat(tokens[i + 3]);
        cx += dx; cy += dy;
        const v1 = this.applyVectorTransform(dx1, dy1, transform);
        const v = this.applyVectorTransform(dx, dy, transform);
        result += ` ${currentCmd} ${v1.x} ${v1.y} ${v.x} ${v.y}`;
        i += 4;
      }
      else if (currentCmd === 'A') {
        const rx = parseFloat(tokens[i]); const ry = parseFloat(tokens[i + 1]);
        const xAxisRot = parseFloat(tokens[i + 2]);
        const largeArc = tokens[i + 3]; let sweep = tokens[i + 4];
        const x = parseFloat(tokens[i + 5]); const y = parseFloat(tokens[i + 6]);
        cx = x; cy = y;

        const angleDeg = Math.atan2(transform.b, transform.a) * 180 / Math.PI;
        const newXAxisRot = xAxisRot + angleDeg;
        const det = transform.a * transform.d - transform.b * transform.c;
        if (det < 0) sweep = sweep === '1' ? '0' : '1';
        const rxTrans = rx * transform.sx;
        const ryTrans = ry * transform.sy;
        const p = this.applyPointTransform(x, y, transform);
        result += ` A ${rxTrans} ${ryTrans} ${newXAxisRot} ${largeArc} ${sweep} ${p.x} ${p.y}`;
        i += 7;
      }
      else if (currentCmd === 'a') {
        const rx = parseFloat(tokens[i]); const ry = parseFloat(tokens[i + 1]);
        const xAxisRot = parseFloat(tokens[i + 2]);
        const largeArc = tokens[i + 3]; let sweep = tokens[i + 4];
        const dx = parseFloat(tokens[i + 5]); const dy = parseFloat(tokens[i + 6]);
        cx += dx; cy += dy;

        const angleDeg = Math.atan2(transform.b, transform.a) * 180 / Math.PI;
        const newXAxisRot = xAxisRot + angleDeg;
        const det = transform.a * transform.d - transform.b * transform.c;
        if (det < 0) sweep = sweep === '1' ? '0' : '1';
        const rxTrans = rx * transform.sx;
        const ryTrans = ry * transform.sy;
        const v = this.applyVectorTransform(dx, dy, transform);
        result += ` a ${rxTrans} ${ryTrans} ${newXAxisRot} ${largeArc} ${sweep} ${v.x} ${v.y}`;
        i += 7;
      }
      else {
        i++;
      }
    }

    return result.trim();
  }

  // 这里的 rect 绘制同样被优化：直接用 L 取代 H 和 V
  private rectToPath(attrs: Record<string, string>, transform: SvgTransform): string {
    const origX = parseFloat(attrs['x'] ?? '0') || 0;
    const origY = parseFloat(attrs['y'] ?? '0') || 0;
    const w = parseFloat(attrs['width'] ?? '0') || 0;
    const h = parseFloat(attrs['height'] ?? '0') || 0;
    if (w <= 0 || h <= 0) return '';

    let rx = parseFloat(attrs['rx'] ?? '0') || 0;
    let ry = parseFloat(attrs['ry'] ?? '0') || 0;
    if (rx > 0 && ry === 0) ry = rx;
    if (ry > 0 && rx === 0) rx = ry;
    rx = Math.min(rx, w / 2);
    ry = Math.min(ry, h / 2);

    let rawD = '';
    if (rx > 0 && ry > 0) {
      rawD = `M ${origX + rx} ${origY} ` +
        `L ${origX + w - rx} ${origY} ` +
        `A ${rx} ${ry} 0 0 1 ${origX + w} ${origY + ry} ` +
        `L ${origX + w} ${origY + h - ry} ` +
        `A ${rx} ${ry} 0 0 1 ${origX + w - rx} ${origY + h} ` +
        `L ${origX + rx} ${origY + h} ` +
        `A ${rx} ${ry} 0 0 1 ${origX} ${origY + h - ry} ` +
        `L ${origX} ${origY + ry} ` +
        `A ${rx} ${ry} 0 0 1 ${origX + rx} ${origY} Z`;
    } else {
      rawD = `M ${origX} ${origY} L ${origX + w} ${origY} L ${origX + w} ${origY + h} L ${origX} ${origY + h} Z`;
    }

    return this.translatePath(rawD, transform);
  }

  private pointsToPath(pointsStr: string, isClosed: boolean, transform: SvgTransform): string {
    if (!pointsStr) return '';
    const nums = pointsStr.trim().split(/[\s,]+/).map((v: string) => parseFloat(v)).filter((n: number) => !isNaN(n));
    if (nums.length < 2) return '';
    const p0 = this.applyPointTransform(nums[0], nums[1], transform);
    let d = `M ${p0.x} ${p0.y}`;
    for (let i = 2; i < nums.length - 1; i += 2) {
      const p = this.applyPointTransform(nums[i], nums[i + 1], transform);
      d += ` L ${p.x} ${p.y}`;
    }
    if (isClosed) d += ' Z';
    return d;
  }

  private traverseNodes(node: Record<string, Object>, parentStyle: SvgInheritedStyle, output: SvgItemData[]): void {
    const children = this.getNodeChildren(node);
    for (const child of children) {
      const tag = this.getNodeName(child);
      if (!tag || tag === 'defs' || tag === 'style' || tag === 'title' || tag === 'desc') continue;

      const attrs = this.getNodeAttributes(child);
      const tf = this.parseTransform(attrs['transform']);
      const parentTf = parentStyle.transform ?? { a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0, sx: 1, sy: 1 };

      const currentStyle: SvgInheritedStyle = {
        fill: attrs['fill'] ?? parentStyle.fill,
        stroke: attrs['stroke'] ?? parentStyle.stroke,
        strokeWidth: attrs['stroke-width'] ?? attrs['strokeWidth'] ?? parentStyle.strokeWidth,
        strokeLineCap: attrs['stroke-linecap'] ?? attrs['strokeLinecap'] ?? parentStyle.strokeLineCap,
        strokeLineJoin: attrs['stroke-linejoin'] ?? attrs['strokeLinejoin'] ?? parentStyle.strokeLineJoin,
        opacity: attrs['opacity'] ?? parentStyle.opacity,
        transform: this.multiplyMatrix(parentTf, tf),
      };

      if (tag === 'g' || tag === 'a') {
        this.traverseNodes(child, currentStyle, output);
        continue;
      }

      const currentTransform = currentStyle.transform!;
      let commands = '';

      if (tag === 'path') {
        commands = this.translatePath(attrs['d'] ?? '', currentTransform);
      } else if (tag === 'line') {
        const p1 = this.applyPointTransform(parseFloat(attrs['x1'] ?? '0') || 0, parseFloat(attrs['y1'] ?? '0') || 0, currentTransform);
        const p2 = this.applyPointTransform(parseFloat(attrs['x2'] ?? '0') || 0, parseFloat(attrs['y2'] ?? '0') || 0, currentTransform);
        commands = `M ${p1.x} ${p1.y} L ${p2.x} ${p2.y}`;
      } else if (tag === 'polyline') {
        commands = this.pointsToPath(attrs['points'] ?? '', false, currentTransform);
      } else if (tag === 'polygon') {
        commands = this.pointsToPath(attrs['points'] ?? '', true, currentTransform);
      } else if (tag === 'rect') {
        commands = this.rectToPath(attrs, currentTransform);
      } else if (tag === 'circle') {
        const p = this.applyPointTransform(parseFloat(attrs['cx'] ?? '0') || 0, parseFloat(attrs['cy'] ?? '0') || 0, currentTransform);
        const r = (parseFloat(attrs['r'] ?? '0') || 0) * Math.min(currentTransform.sx, currentTransform.sy);
        if (r > 0) commands = `M ${p.x - r} ${p.y} A ${r} ${r} 0 1 0 ${p.x + r} ${p.y} A ${r} ${r} 0 1 0 ${p.x - r} ${p.y} Z`;
      } else if (tag === 'ellipse') {
        const p = this.applyPointTransform(parseFloat(attrs['cx'] ?? '0') || 0, parseFloat(attrs['cy'] ?? '0') || 0, currentTransform);
        const rx = (parseFloat(attrs['rx'] ?? '0') || 0) * currentTransform.sx;
        const ry = (parseFloat(attrs['ry'] ?? '0') || 0) * currentTransform.sy;
        if (rx > 0 && ry > 0) commands = `M ${p.x - rx} ${p.y} A ${rx} ${ry} 0 1 0 ${p.x + rx} ${p.y} A ${rx} ${ry} 0 1 0 ${p.x - rx} ${p.y} Z`;
      }

      if (!commands.trim()) continue;

      let resolvedFill: ResourceColor = 'none';
      if (this.fill !== undefined) {
        resolvedFill = currentStyle.fill === 'none' ? 'none' : this.fill;
      } else {
        if (currentStyle.fill === 'none') {
          resolvedFill = 'none';
        } else if (currentStyle.fill) {
          resolvedFill = currentStyle.fill === 'currentColor' ? (this.stroke ?? '#000000') : currentStyle.fill;
        } else {
          resolvedFill = (currentStyle.stroke && currentStyle.stroke !== 'none') ? 'none' : '#000000';
        }
      }

      let resolvedStroke: ResourceColor = 'none';
      if (this.stroke !== undefined) {
        resolvedStroke = (currentStyle.stroke && currentStyle.stroke !== 'none') || currentStyle.fill === 'none'
          ? this.stroke : (currentStyle.stroke === 'none' ? 'none' : this.stroke);
      } else {
        if (!currentStyle.stroke || currentStyle.stroke === 'none') {
          resolvedStroke = 'none';
        } else {
          resolvedStroke = currentStyle.stroke === 'currentColor' ? (this.fill ?? '#000000') : currentStyle.stroke;
        }
      }

      let resolvedStrokeWidth: number = 1;
      if (this.strokeWidth !== undefined) {
        resolvedStrokeWidth = this.strokeWidth;
      } else if (currentStyle.strokeWidth) {
        const parsedSw = parseFloat(currentStyle.strokeWidth);
        resolvedStrokeWidth = isNaN(parsedSw) ? 1 : parsedSw;
      } else {
        resolvedStrokeWidth = resolvedStroke === 'none' ? 0 : 1;
      }

      const opacity = currentStyle.opacity ? parseFloat(currentStyle.opacity) : 1;

      output.push({
        id: `svg_item_${output.length}`,
        commands: commands,
        fill: resolvedFill,
        stroke: resolvedStroke,
        strokeWidth: resolvedStrokeWidth,
        strokeLineCap: this.parseLineCap(currentStyle.strokeLineCap),
        strokeLineJoin: this.parseLineJoin(currentStyle.strokeLineJoin),
        opacity: isNaN(opacity) ? 1 : opacity
      });
    }
  }

  private parseLineCap(val?: string): LineCapStyle | undefined {
    if (!val) return undefined;
    const s = val.toLowerCase().trim();
    if (s === 'round') return LineCapStyle.Round;
    if (s === 'square') return LineCapStyle.Square;
    if (s === 'butt') return LineCapStyle.Butt;
    return undefined;
  }

  private parseLineJoin(val?: string): LineJoinStyle | undefined {
    if (!val) return undefined;
    const s = val.toLowerCase().trim();
    if (s === 'round') return LineJoinStyle.Round;
    if (s === 'miter') return LineJoinStyle.Miter;
    if (s === 'bevel') return LineJoinStyle.Miter;
    return undefined;
  }

  build() {
    Stack() {
      ForEach(this.items, (item: SvgItemData) => {
        Shape() {
          Path()
            .commands(item.commands)
            .fill(item.fill)
            .stroke(item.stroke)
            .strokeWidth(item.strokeWidth + 'px')
            .strokeLineCap(item.strokeLineCap ?? LineCapStyle.Round)
            .strokeLineJoin(item.strokeLineJoin ?? LineJoinStyle.Round)
        }
        .viewPort({
          x: this.viewBoxX + 'px',
          y: this.viewBoxY + 'px',
          width: this.viewBoxWidth + 'px',
          height: this.viewBoxHeight + 'px'
        })
        .width('100%')
        .height('100%')
        .opacity(item.opacity ?? 1)
      }, (item: SvgItemData) => item.id)
    }
    .width(this.renderWidth)
    .height(this.renderHeight)
  }
}