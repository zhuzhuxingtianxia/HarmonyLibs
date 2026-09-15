import { convertxml, buffer, JSON } from "@kit.ArkTS";

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
    const size = this.viewBoxWidth > 0 ? this.viewBoxWidth : 24;
    return size;
  }

  private get renderHeight(): Length {
    if (this.bounds !== undefined && this.bounds > 0) {
      return this.bounds;
    }
    if (this.svgHeight > 0) {
      return this.svgHeight;
    }
    const size = this.viewBoxHeight > 0 ? this.viewBoxHeight : 24;
    return size;
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
        transform: {
          tx: 0,
          ty: 0,
          sx: 1,
          sy: 1
        },
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
      const keys = Object.keys(rawAttrs);
      for (const k of keys) {
        result[k] = String(rawAttrs[k]);
      }
    }
    if (result['style']) {
      const styleObj = this.parseStyleAttr(result['style']);
      const styleKeys = Object.keys(styleObj);
      for (const sk of styleKeys) {
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

  private parseTransform(transformStr?: string): SvgTransform {
    let a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0;

    if (!transformStr) {
      return { tx: 0, ty: 0, sx: 1, sy: 1 };
    }

    const regex = /(matrix|translate|scale)\s*\(([^)]+)\)/g;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(transformStr)) !== null) {
      const type = match[1];
      const args = match[2].trim().split(/[\s,]+/).map((v: string) => parseFloat(v));

      let ma = 1, mb = 0, mc = 0, md = 1, mtx = 0, mty = 0;

      if (type === 'matrix' && args.length >= 6) {
        ma = args[0]; mb = args[1]; mc = args[2]; md = args[3]; mtx = args[4]; mty = args[5];
      } else if (type === 'translate') {
        mtx = args[0] || 0;
        mty = args[1] !== undefined ? args[1] : 0;
      } else if (type === 'scale') {
        ma = args[0] !== undefined ? args[0] : 1;
        md = args[1] !== undefined ? args[1] : ma;
      }

      const newA = a * ma + c * mb;
      const newB = b * ma + d * mb;
      const newC = a * mc + c * md;
      const newD = b * mc + d * md;
      const newTx = a * mtx + c * mty + tx;
      const newTy = b * mtx + d * mty + ty;

      a = newA; b = newB; c = newC; d = newD; tx = newTx; ty = newTy;
    }

    return { tx, ty, sx: a, sy: d };
  }

  private translatePath(d: string, transform: SvgTransform = {tx:0, ty:0, sx: 1, sy: 1}): string {
    if (!d || (transform.tx === 0 && transform.ty === 0 && transform.sx === 1 && transform.sy === 1)) {
      return d;
    }
    const tokens = d.match(/[a-df-z]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?/gi);
    if (!tokens) {
      return d;
    }

    let result = '';
    let currentCmd = '';
    let i = 0;

    while (i < tokens.length) {
      const token = tokens[i];
      if (/^[a-df-z]$/i.test(token)) {
        currentCmd = token;
        result += (result ? ' ' : '') + currentCmd;
        i++;
      } else {
        if (currentCmd === 'M' || currentCmd === 'L' || currentCmd === 'T') {
          const x = (parseFloat(tokens[i]) * transform.sx) + transform.tx;
          const y = (parseFloat(tokens[i + 1]) * transform.sy) + transform.ty;
          result += ` ${x} ${y}`;
          i += 2;
          if (currentCmd === 'M') {
            currentCmd = 'L';
          }
        } else if (currentCmd === 'm') {
          if (i === 1) {
            const x = (parseFloat(tokens[i]) * transform.sx) + transform.tx;
            const y = (parseFloat(tokens[i + 1]) * transform.sy) + transform.ty;
            result += ` ${x} ${y}`;
          } else {
            result += ` ${parseFloat(tokens[i]) * transform.sx} ${parseFloat(tokens[i + 1]) * transform.sy}`;
          }
          i += 2;
          currentCmd = 'l';
        } else if (currentCmd === 'l' || currentCmd === 't') {
          result += ` ${parseFloat(tokens[i]) * transform.sx} ${parseFloat(tokens[i + 1]) * transform.sy}`;
          i += 2;
        } else if (currentCmd === 'H') {
          const x = (parseFloat(tokens[i]) * transform.sx) + transform.tx;
          result += ` ${x}`;
          i += 1;
        } else if (currentCmd === 'h') {
          result += ` ${parseFloat(tokens[i]) * transform.sx}`;
          i += 1;
        } else if (currentCmd === 'V') {
          const y = (parseFloat(tokens[i]) * transform.sy) + transform.ty;
          result += ` ${y}`;
          i += 1;
        } else if (currentCmd === 'v') {
          result += ` ${parseFloat(tokens[i]) * transform.sy}`;
          i += 1;
        } else if (currentCmd === 'C') {
          const x1 = (parseFloat(tokens[i]) * transform.sx) + transform.tx;
          const y1 = (parseFloat(tokens[i + 1]) * transform.sy) + transform.ty;
          const x2 = (parseFloat(tokens[i + 2]) * transform.sx) + transform.tx;
          const y2 = (parseFloat(tokens[i + 3]) * transform.sy) + transform.ty;
          const x = (parseFloat(tokens[i + 4]) * transform.sx) + transform.tx;
          const y = (parseFloat(tokens[i + 5]) * transform.sy) + transform.ty;
          result += ` ${x1} ${y1} ${x2} ${y2} ${x} ${y}`;
          i += 6;
        } else if (currentCmd === 'c') {
          const x1 = parseFloat(tokens[i]) * transform.sx;
          const y1 = parseFloat(tokens[i + 1]) * transform.sy;
          const x2 = parseFloat(tokens[i + 2]) * transform.sx;
          const y2 = parseFloat(tokens[i + 3]) * transform.sy;
          const x = parseFloat(tokens[i + 4]) * transform.sx;
          const y = parseFloat(tokens[i + 5]) * transform.sy;
          result += ` ${x1} ${y1} ${x2} ${y2} ${x} ${y}`;
          i += 6;
        } else if (currentCmd === 'S' || currentCmd === 'Q') {
          const x1 = (parseFloat(tokens[i]) * transform.sx) + transform.tx;
          const y1 = (parseFloat(tokens[i + 1]) * transform.sy) + transform.ty;
          const x = (parseFloat(tokens[i + 2]) * transform.sx) + transform.tx;
          const y = (parseFloat(tokens[i + 3]) * transform.sy) + transform.ty;
          result += ` ${x1} ${y1} ${x} ${y}`;
          i += 4;
        } else if (currentCmd === 's' || currentCmd === 'q') {
          const x1 = parseFloat(tokens[i]) * transform.sx;
          const y1 = parseFloat(tokens[i + 1]) * transform.sy;
          const x = parseFloat(tokens[i + 2]) * transform.sx;
          const y = parseFloat(tokens[i + 3]) * transform.sy;
          result += ` ${x1} ${y1} ${x} ${y}`;
          i += 4;
        } else if (currentCmd === 'A') {
          const rx = parseFloat(tokens[i]) * Math.abs(transform.sx);
          const ry = parseFloat(tokens[i + 1]) * Math.abs(transform.sy);
          const rot = tokens[i + 2];
          const large = tokens[i + 3];
          const sweep = (transform.sx * transform.sy < 0) ? (tokens[i + 4] === '1' ? '0' : '1') : tokens[i + 4];
          const x = (parseFloat(tokens[i + 5]) * transform.sx) + transform.tx;
          const y = (parseFloat(tokens[i + 6]) * transform.sy) + transform.ty;
          result += ` ${rx} ${ry} ${rot} ${large} ${sweep} ${x} ${y}`;
          i += 7;
        } else if (currentCmd === 'a') {
          const rx = parseFloat(tokens[i]) * Math.abs(transform.sx);
          const ry = parseFloat(tokens[i + 1]) * Math.abs(transform.sy);
          const rot = tokens[i + 2];
          const large = tokens[i + 3];
          const sweep = (transform.sx * transform.sy < 0) ? (tokens[i + 4] === '1' ? '0' : '1') : tokens[i + 4];
          const x = parseFloat(tokens[i + 5]) * transform.sx;
          const y = parseFloat(tokens[i + 6]) * transform.sy;
          result += ` ${rx} ${ry} ${rot} ${large} ${sweep} ${x} ${y}`;
          i += 7;
        } else if (currentCmd === 'Z' || currentCmd === 'z') {
          i++;
        } else {
          result += ` ${tokens[i]}`;
          i++;
        }
      }
    }

    return result;
  }

  private traverseNodes(node: Record<string, Object>, parentStyle: SvgInheritedStyle, output: SvgItemData[]): void {
    const children = this.getNodeChildren(node);
    for (const child of children) {
      const tag = this.getNodeName(child);
      if (!tag || tag === 'defs' || tag === 'style' || tag === 'title' || tag === 'desc') {
        continue;
      }

      const attrs = this.getNodeAttributes(child);
      const tf = this.parseTransform(attrs['transform']);
      const parentTf = parentStyle.transform ?? { tx: 0, ty: 0, sx: 1, sy: 1 };

      const currentStyle: SvgInheritedStyle = {
        fill: attrs['fill'] ?? parentStyle.fill,
        stroke: attrs['stroke'] ?? parentStyle.stroke,
        strokeWidth: attrs['stroke-width'] ?? attrs['strokeWidth'] ?? parentStyle.strokeWidth,
        strokeLineCap: attrs['stroke-linecap'] ?? attrs['strokeLinecap'] ?? parentStyle.strokeLineCap,
        strokeLineJoin: attrs['stroke-linejoin'] ?? attrs['strokeLinejoin'] ?? parentStyle.strokeLineJoin,
        opacity: attrs['opacity'] ?? parentStyle.opacity,
        transform: {
          tx: parentTf.tx + tf.tx * parentTf.sx,
          ty: parentTf.ty + tf.ty * parentTf.sy,
          sx: parentTf.sx * tf.sx,
          sy: parentTf.sy * tf.sy
        },
      };

      if (tag === 'g' || tag === 'a') {
        this.traverseNodes(child, currentStyle, output);
        continue;
      }

      const curTx = currentStyle.transform!.tx;
      const curTy = currentStyle.transform!.ty;
      const curSx = currentStyle.transform!.sx;
      const curSy = currentStyle.transform!.sy;

      let commands = '';
      if (tag === 'path') {
        const rawD = attrs['d'] ?? '';
        commands = this.translatePath(rawD, currentStyle.transform);
      } else if (tag === 'line') {
        const x1 = ((parseFloat(attrs['x1'] ?? '0') || 0) * curSx) + curTx;
        const y1 = ((parseFloat(attrs['y1'] ?? '0') || 0) * curSy) + curTy;
        const x2 = ((parseFloat(attrs['x2'] ?? '0') || 0) * curSx) + curTx;
        const y2 = ((parseFloat(attrs['y2'] ?? '0') || 0) * curSy) + curTy;
        commands = `M ${x1} ${y1} L ${x2} ${y2}`;
      } else if (tag === 'polyline') {
        commands = this.pointsToPath(attrs['points'] ?? '', false, currentStyle.transform);
      } else if (tag === 'polygon') {
        commands = this.pointsToPath(attrs['points'] ?? '', true, currentStyle.transform);
      } else if (tag === 'rect') {
        commands = this.rectToPath(attrs, currentStyle.transform);
      } else if (tag === 'circle') {
        const cx = ((parseFloat(attrs['cx'] ?? '0') || 0) * curSx) + curTx;
        const cy = ((parseFloat(attrs['cy'] ?? '0') || 0) * curSy) + curTy;
        const r = (parseFloat(attrs['r'] ?? '0') || 0) * Math.min(Math.abs(curSx), Math.abs(curSy));
        if (r > 0) {
          commands = `M ${cx - r} ${cy} A ${r} ${r} 0 1 0 ${cx + r} ${cy} A ${r} ${r} 0 1 0 ${cx - r} ${cy} Z`;
        }
      } else if (tag === 'ellipse') {
        const cx = ((parseFloat(attrs['cx'] ?? '0') || 0) * curSx) + curTx;
        const cy = ((parseFloat(attrs['cy'] ?? '0') || 0) * curSy) + curTy;
        const rx = (parseFloat(attrs['rx'] ?? '0') || 0) * Math.abs(curSx);
        const ry = (parseFloat(attrs['ry'] ?? '0') || 0) * Math.abs(curSy);
        if (rx > 0 && ry > 0) {
          commands = `M ${cx - rx} ${cy} A ${rx} ${ry} 0 1 0 ${cx + rx} ${cy} A ${rx} ${ry} 0 1 0 ${cx - rx} ${cy} Z`;
        }
      }

      if (!commands.trim()) {
        continue;
      }

      // 计算最终 fill
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

      // 计算最终 stroke
      let resolvedStroke: ResourceColor = 'none';
      if (this.stroke !== undefined) {
        resolvedStroke = (currentStyle.stroke && currentStyle.stroke !== 'none') || currentStyle.fill === 'none'
          ? this.stroke
          : (currentStyle.stroke === 'none' ? 'none' : this.stroke);
      } else {
        if (currentStyle.stroke === 'none' || !currentStyle.stroke) {
          resolvedStroke = 'none';
        } else {
          resolvedStroke = currentStyle.stroke === 'currentColor' ? (this.fill ?? '#000000') : currentStyle.stroke;
        }
      }

      // 计算最终 strokeWidth
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

  private pointsToPath(pointsStr: string, isClosed: boolean, transform: SvgTransform = {tx:0, ty:0, sx: 1, sy: 1}): string {
    if (!pointsStr) return '';
    const nums = pointsStr.trim().split(/[\s,]+/).map((v: string) => parseFloat(v)).filter((n: number) => !isNaN(n));
    if (nums.length < 2) return '';
    let d = `M ${(nums[0] * transform.sx) + transform.tx} ${(nums[1] * transform.sy) + transform.ty}`;
    for (let i = 2; i < nums.length - 1; i += 2) {
      d += ` L ${(nums[i] * transform.sx) + transform.tx} ${(nums[i + 1] * transform.sy) + transform.ty}`;
    }
    if (isClosed) {
      d += ' Z';
    }
    return d;
  }

  private rectToPath(attrs: Record<string, string>, transform: SvgTransform = {tx:0, ty:0, sx: 1, sy: 1}): string {
    const x = ((parseFloat(attrs['x'] ?? '0') || 0) * transform.sx) + transform.tx;
    const y = ((parseFloat(attrs['y'] ?? '0') || 0) * transform.sy) + transform.ty;
    const w = (parseFloat(attrs['width'] ?? '0') || 0) * transform.sx;
    const h = (parseFloat(attrs['height'] ?? '0') || 0) * transform.sy;
    if (w === 0 || h === 0) return '';

    let rx = (parseFloat(attrs['rx'] ?? '0') || 0) * Math.abs(transform.sx);
    let ry = (parseFloat(attrs['ry'] ?? '0') || 0) * Math.abs(transform.sy);
    if (rx > 0 && ry === 0) ry = rx;
    if (ry > 0 && rx === 0) rx = ry;
    rx = Math.min(rx, Math.abs(w) / 2);
    ry = Math.min(ry, Math.abs(h) / 2);

    if (rx > 0 && ry > 0) {
      return `M ${x + rx} ${y} ` +
        `H ${x + w - rx} ` +
        `A ${rx} ${ry} 0 0 1 ${x + w} ${y + ry} ` +
        `V ${y + h - ry} ` +
        `A ${rx} ${ry} 0 0 1 ${x + w - rx} ${y + h} ` +
        `H ${x + rx} ` +
        `A ${rx} ${ry} 0 0 1 ${x} ${y + h - ry} ` +
        `V ${y + ry} ` +
        `A ${rx} ${ry} 0 0 1 ${x + rx} ${y} Z`;
    }
    return `M ${x} ${y} H ${x + w} V ${y + h} H ${x} Z`;
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