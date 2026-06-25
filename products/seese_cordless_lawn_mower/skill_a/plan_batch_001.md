---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 5aa86fae1f63d873f6d2f4ecb348c8a3_8de832e26f9a11f1aabe5254007bceed
    ReservedCode1: Fp9UEiHiJxF4FY9geeHyfZXKwdmp/q62UlwKzn9V0cjbTvoW9W/20maLRjWVOqehXNBQuKm+Y13C9BPZD4rGErSjJYztgUDLWyDKXKAHAZF1eRAjADCiieePxdS3uFsaNQopWiblKKGHuO5rS1lVUv1BsG9vbnHswVX7uW/Eo10etc1WrTvqp1fOglQ=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 5aa86fae1f63d873f6d2f4ecb348c8a3_8de832e26f9a11f1aabe5254007bceed
    ReservedCode2: Fp9UEiHiJxF4FY9geeHyfZXKwdmp/q62UlwKzn9V0cjbTvoW9W/20maLRjWVOqehXNBQuKm+Y13C9BPZD4rGErSjJYztgUDLWyDKXKAHAZF1eRAjADCiieePxdS3uFsaNQopWiblKKGHuO5rS1lVUv1BsG9vbnHswVX7uW/Eo10etc1WrTvqp1fOglQ=
---

# SEESE Cordless Lawn Mower — UCG Omini 视频制作方案

> **批次**: batch_001 | **SKU**: SEESE Cordless Lawn Mower | **方案生成时间**: 2026-06-24

---

## 1. 默认制作参数确认表

| 参数项 | 设定值 | 备注 |
|--------|--------|------|
| 目标市场 | 美国 | TikTok media buying 语境 |
| 口播语言 | 美式英语 | 所有脚本 / Hook 均为美式英语 |
| 规划/提示词语言 | 中文 | Omini prompt 用中文编写 |
| 画幅 | 9:16 竖屏 | 手机原生观看体验 |
| 成片时长 | 30 秒 | 3 段 × 10 秒 |
| 第 4 段 B-roll | 8-10 秒 | 独立补位素材，不计入成片 |
| 视觉风格 | 真实手机手持 UGC 测评质感 | 自然创作者内容，非广告片 |
| 视频形式 | 手持演示 + 口播 | 户外草坪场景 |
| 主推卖点 | 3 合 1 多功能（割草+修边+打草）+ 无刷电机 | 优先在前两段露出 |
| 虚拟达人 | 非亚裔，白人男性 | 年龄/发型/服装/场景固定，无分支词 |
| 字幕 | 后期添加 | 不由视频模型生成 |
| 平台水印/UI | 禁止 | 不得出现 TikTok 等平台标识 |

---

## 2. Skill A 标准参考资产读取结果

**产品信息源**: `E:\test001-1\product_reference_pack\SEESE Cordless Lawn Mower\product_profile.yaml`

### 关键视觉事实

| 维度 | 事实 |
|------|------|
| 主色 | 青柠绿（lime green）+ 黑色 |
| 材质 | 塑料外壳 + 金属切割组件 + 橡胶握把 |
| 形态 | 可伸缩轴杆 + 顶部 D 型手柄 + 底部电机壳 + 3合1切割头 |
| Logo 位置 | 电机外壳（SEESE 品牌） |
| 切割宽度 | 13.7 英寸 |
| 重量 | 10 磅 |
| 关键特征 | D 型手柄（扳机开关+安全开关）、伸缩轴杆调节开关、无刷电机外壳（下端）、3合1切割头（割草刀片+打草线轴+修边刀片）、双 21V 电池包安装于电机外壳 |

### 参考图资产

| 类型 | 本地路径 | 状态 |
|------|----------|------|
| product_white_bg | `E:\test001-1\product_reference_pack\SEESE Cordless Lawn Mower\images\product_white_bg.png` | 已就绪 |
| product_detail_side | `E:\test001-1\product_reference_pack\SEESE Cordless Lawn Mower\images\product_detail_side.png` | **缺失** — 后续prompt中标注"参考图未明确展示该视角" |
| product_function | `E:\test001-1\product_reference_pack\SEESE Cordless Lawn Mower\images\product_function.png` | 已就绪 |

### must_keep 约束

- 保持产品颜色不变
- 保持产品形状不变
- 保持产品材质不变
- 保持产品比例不变
- 保持 Logo 位置不变
- 不要增加原始产品不存在的配件

### must_avoid 约束

- 不要改变产品品类
- 不要虚构不存在的功能
- 不要增加多余按钮、灯光、接口或装饰
- 不要改变包装、结构、纹理和视觉比例

### 待确认项

- `product_detail_side.png` 缺失：涉及无刷电机近距离特写时，prompt 仅依赖 `product_white_bg.png` 中可见的电机外壳外观，不做内部结构推测
- 尚无历史 `video_fingerprint_memory.md` 和 `history/prompt_payloads_*.json`：本次为首次生成，无需反重复参考

---

## 3. 本次视频反重复策略

- **历史相似风险**：无（首次为该 SKU 生成视频方案，无历史指纹记录）
- **本次达人变化**：首次设定 — 白人男性，35-40 岁，短发深棕色，短袖 Polo 衫，户外草坪后院
- **本次场景变化**：首次设定 — 郊区后院草坪，午后自然光，面积约 200-400 平方英尺
- **本次开头画面变化**：手持手机 POV 拍摄杂草丛生的草坪边缘（痛点画面），第 1 秒直接呈现杂草问题
- **本次镜头结构变化**：痛点自拍 → 产品手持演示 → 功能特写 → 使用结果对比（POV 与 selfie 穿插）
- **本次产品动作顺序变化**：割草 → 修边 → 打草 → 展示无刷电机高效运转
- **本次第 4 段补位素材变化**：独立展示伸缩轴杆调节 + 电池拆装 + 切割头特写

---

## 4. 产品与受众判断

**产品**: SEESE 无线割草机 — 3合1（割草/修边/打草），无刷电机，轻量 10 磅，适合中小型后院

**目标受众（美国市场）**:
- 郊区 homeowner，25-55 岁，拥有中小型后院（200-1000 sq ft）
- 追求性价比和便捷性的 DIY 草坪维护者
- 已厌倦有线/燃油设备的繁琐与噪音，愿意尝试无线电动工具
- 购买动机：省时、省力、一机多用、无线自由

**核心痛点**:
- 有线割草机拖拽不便，受电源插座限制
- 燃油设备噪音大、维护麻烦、启动困难
- 需要多台工具分别完成割草、修边、打草 — 成本高且占存储空间
- 传统割草机笨重（>30 lbs），小面积草坪用起来浪费

**竞品对比语境**: 对标 Greenworks / Worx / Sun Joe 等入门级无线割草机，突出 3 合 1 和无刷电机差异化

---

## 5. 视频形式与创意逻辑

**视频形式**: 手持演示 + 口播（mixed POV + selfie），户外草坪场景

**创意逻辑**:

1. **段 1（00:00-00:10）— 痛点 + 产品亮相**: 从杂草丛生的草坪边缘痛点切入，引出 SEESE 无线割草机，强调"一台搞定三种活"
2. **段 2（00:00-00:10）— 无刷电机 + 实际割草演示**: 推着 SEESE 在草坪上割草，展示无刷电机的安静高效，口播强调"50% longer runtime, 25% more power"
3. **段 3（00:00-00:10）— 修边+打草 + 结果**: 切换到修边和打草模式，展示 3 合 1 完整覆盖，最后展示整洁草坪结果
4. **第 4 段 B-roll（8-10 秒）**: 伸缩轴杆调节 + 电池拆装 + 切割头旋转特写，作为前三段补位素材

**叙事策略**: "I used to need three tools" → "Now this one does it all" → "Look at this lawn"

---

## 6. 虚拟达人设定

| 属性 | 设定 | 约束 |
|------|------|------|
| 种族 | 白人（Caucasian） | 非亚裔 |
| 性别 | 男性 | — |
| 年龄 | 37 岁 | 稳定不变 |
| 发型 | 深棕色短发，略微灰白鬓角，自然偏分 | 不戴帽子 |
| 面部 | 干净胡茬（stubble），方脸，蓝灰色眼睛 | 无眼镜 |
| 体型 | 中等偏瘦，5'10"，约 170 lbs | — |
| 服装 | 深蓝色短袖 Polo 衫（无 logo），卡其色工装短裤 | 不变 |
| 鞋子 | 棕色户外运动鞋 | — |
| 场景 | 郊区后院草坪，面积约 300 sq ft，午后 3-4 点自然光 | 阳光充足，不逆光 |
| 表情/性格 | 务实、友善、自信但不夸张，类似邻居推荐 | — |
| 手持方式 | 右手持手机自拍 / POV 拍摄，左手操作产品 | — |
| 环境元素 | 草坪边缘有木质围栏，角落有几株灌木，无其他人物 | 无品牌标识 |

---

## 7. 达人/场景参考图提示词

```
生成一张9:16竖屏参考图，用于AI视频模型作为达人身份锚点。
白人男性，37岁，深棕色短发，蓝灰色眼睛，干净胡茬，方脸。
身穿深蓝色短袖Polo衫（纯色无logo），卡其色工装短裤，棕色户外运动鞋。
站在美国郊区后院草坪上，面积约300平方英尺，午后自然阳光，草坪边缘有木质围栏和少量灌木。
达人正面站立看向摄像头，自然友善表情，右手持智能手机在胸前高度做自拍姿势，左手垂在身侧。
画面中不得出现任何产品、包装、品牌标志、文字、水印或UI元素。
画面真实自然，像随手拍摄的生活照，不做夸张后期处理。
```

---

## 8. 10 条 Hook

| # | 类型 | English Hook | 中文翻译 |
|---|------|-------------|----------|
| 1 | **Pain Point** | "I was so tired of dragging an extension cord across my yard every weekend." | "我受够了每个周末都要拖着延长线穿过院子。" |
| 2 | **Curiosity** | "This one tool replaced three things in my garage — and it's only 10 pounds." | "这一个工具替换了我车库里的三样东西——而且只有 10 磅重。" |
| 3 | **Social Proof** | "My neighbor asked who I hired to do my lawn. I showed him this." | "邻居问我雇了谁来做草坪。我给他看了这个。" |
| 4 | **Contradiction** | "I thought going cordless meant sacrificing power. I was wrong." | "我以为无线意味着牺牲动力。我错了。" |
| 5 | **Mistake** | "I almost bought three separate tools before I found this 3-in-1." | "我差点买了三台独立的工具，然后发现了这个三合一。" |
| 6 | **Scenario** | "Sunday morning, cup of coffee, and 20 minutes to a perfect lawn." | "周日早晨，一杯咖啡，20 分钟搞定完美草坪。" |
| 7 | **Challenge** | "Show me another cordless mower that also trims and edges for under two hundred." | "给我看另一台两百美元以下、还能打草和修边的无线割草机。" |
| 8 | **Comparison** | "My old gas mower weighed 35 pounds. This one's 10 and does three times the work." | "我的旧燃油割草机重 35 磅。这台 10 磅，做三倍的活。" |
| 9 | **Confession** | "I didn't believe the brushless motor hype until I timed how long this ran." | "我不信无刷电机的宣传，直到我计时它运行了多久。" |
| 10 | **Direct Benefit** | "If you've got a small to medium backyard, this is the only lawn tool you need." | "如果你有一个中小型后院，这是你唯一需要的草坪工具。" |

---

## 9. 30 秒正片：口播脚本 + B-roll 镜头清单 + Omini 可直接粘贴的视频生成提示词

---

### 段 1（Segment 01）：痛点 + 产品亮相

#### 口播脚本（≤30 词，美式英语）

"This is what my lawn edges looked like every spring. Overgrown, messy, and honestly embarrassing. But then I found this SEESE 3-in-1 cordless mower."

#### B-roll 镜头清单（中文）

- POV 俯拍：杂草丛生的草坪边缘，午后阳光
- 自拍：达人面对镜头，表情无奈
- 中景：达人从画面左侧拿出 SEESE 割草机，金色阳光下青柠绿机身醒目
- 手持特写：SEESE 3合1切割头，旋转展示刀片/打草线/修边刀
- 远景：达人站在整洁草坪起点，手持割草机，准备开始

#### Omini 可直接粘贴的视频生成提示词

```
画面中不得出现任何平台水印、TikTok水印、App界面、账号栏、点赞评论分享按钮、平台Logo、自动字幕、贴纸文字或边框UI。
生成一段10秒9:16竖屏美国社交媒体短视频广告，真实手机手持UGC测评质感。参考图1中的固定白人男性达人在郊区后院草坪（约300平方英尺，午后自然光），使用参考图2中的SEESE无线割草机。产品只参考Skill A标准参考图，保持青柠绿+黑色配色、D型手柄、可伸缩轴杆、3合1切割头、双21V电池包、SEESE电机外壳Logo一致，不参考原始海报、尺寸图、文字卖点图或对比图，不生成尺寸线，不生成说明文字，不改变产品结构。画面自然真实，像创作者用手机随手拍摄。

00:00-00:00.5，POV俯拍镜头，杂草丛生的草坪边缘与木质围栏边界，杂草高矮不齐，午后阳光斜照，画面呈现"被忽视的草坪"真实感。
00:00.5-00:01.0，自拍镜头，达人对镜头无奈摇头，表情自然不夸张，身后可见杂草背景。
00:01.0-00:01.5，自拍镜头，达人表情转折为"有解决方案"，右手从画面下方拿起SEESE割草机，青柠绿机身出现在画面中。
00:01.5-00:03.0，手持特写镜头，达人的手旋转SEESE割草机的3合1切割头，依次展示割草刀片、打草线轴、修边刀片，动作自然稳健。
00:03.0-00:06.0，中景跟拍镜头，达人双手握住D型手柄，将SEESE割草机放在草坪上准备开始，镜头从侧面低角度跟拍。
00:06.0-00:10.0，远景镜头，达人站在整洁草坪起点位置，手持SEESE割草机，阳光下青柠绿机身与绿色草坪形成鲜明对比，画面干净有力。

同步美式英语口播："This is what my lawn edges looked like every spring. Overgrown, messy, and honestly embarrassing. But then I found this SEESE 3-in-1 cordless mower."
保留自然环境声、轻微产品声音和真实手机手持感。字幕后期添加，不由视频模型生成文字。
must_keep：保持产品青柠绿+黑色配色、D型手柄形状、可伸缩轴杆、3合1切割头结构、双21V电池包位置、SEESE电机外壳Logo不变，不要增加原始产品不存在的配件。
must_avoid：不要改变产品品类为其他工具，不要虚构不存在的功能，不要增加多余按钮/灯光/接口/装饰，不要改变包装/结构/纹理/视觉比例，不出现原始海报中的文字/图表/箭头/尺寸标注。
```

---

### 段 2（Segment 02）：无刷电机 + 割草演示

#### 口播脚本（≤30 词，美式英语）

"This brushless motor is crazy efficient. Fifty percent longer runtime, twenty-five percent more power. Look how clean that cut is — 13.7-inch swath, one pass."

#### B-roll 镜头清单（中文）

- 中景：达人推着 SEESE 在草坪上前进，割出一条清晰的路径
- 特写：无刷电机外壳，手指轻触电机外壳表面
- POV：割草后的草坪切面对比 — 左边未割/右边已割
- 中景：达人轻松单手拎起 SEESE，展示 10 磅轻量
- 特写：割草刀片在阳光下旋转，切割草叶

#### Omini 可直接粘贴的视频生成提示词

```
画面中不得出现任何平台水印、TikTok水印、App界面、账号栏、点赞评论分享按钮、平台Logo、自动字幕、贴纸文字或边框UI。
生成一段10秒9:16竖屏美国社交媒体短视频广告，真实手机手持UGC测评质感。参考图1中的固定白人男性达人在郊区后院草坪（约300平方英尺，午后自然光），使用参考图2中的SEESE无线割草机。产品只参考Skill A标准参考图，保持青柠绿+黑色配色、D型手柄、可伸缩轴杆、3合1切割头、双21V电池包、SEESE电机外壳Logo一致，不参考原始海报、尺寸图、文字卖点图或对比图，不生成尺寸线，不生成说明文字，不改变产品结构。画面自然真实，像创作者用手机随手拍摄。

00:00-00:02.0，中景跟拍镜头，达人双手握住D型手柄，将SEESE割草机平稳推过草坪，割出一条清晰整洁的路径，动作自然有节奏。
00:02.0-00:04.0，低角度POV特写，割草刀片在草丛中旋转切割，草叶向后飞散，无刷电机运转声音轻微，画面有真实动感。
00:04.0-00:06.0，手持中景镜头，达人右手单手轻松拎起SEESE割草机至胸前高度，展示10磅轻量，表情自信满意。
00:06.0-00:08.0，POV特写，手掌轻拍SEESE无刷电机外壳，手指指向SEESE Logo，然后指向刚割完的草坪。
00:08.0-00:10.0，远景对比镜头，画面同时展示割草前杂草丛生区域与割草后整洁区域，阳光明亮，草坪纹理清晰。

同步美式英语口播："This brushless motor is crazy efficient. Fifty percent longer runtime, twenty-five percent more power. Look how clean that cut is — 13.7-inch swath, one pass."
保留自然环境声、轻微产品声音和真实手机手持感。字幕后期添加，不由视频模型生成文字。
must_keep：保持产品青柠绿+黑色配色、D型手柄形状、可伸缩轴杆、3合1切割头结构、双21V电池包位置、SEESE电机外壳Logo不变，不要增加原始产品不存在的配件。
must_avoid：不要改变产品品类为其他工具，不要虚构不存在的功能，不要增加多余按钮/灯光/接口/装饰，不要改变包装/结构/纹理/视觉比例，不出现原始海报中的文字/图表/箭头/尺寸标注。
```

---

### 段 3（Segment 03）：修边+打草 + 结果展示

#### 口播脚本（≤30 词，美式英语）

"Switch to edger mode for the borders and trimmer mode for tight spots. Three functions, one tool, no cords. This backyard took me twenty minutes."

#### B-roll 镜头清单（中文）

- 中景：达人调整切割头从割草模式切换到修边模式
- POV 低角度：修边刀片沿草坪边缘与围栏之间推进
- 自拍：达人手持 SEESE 对镜头满意微笑，身后整洁草坪
- POV 特写：打草线在狭窄角落快速旋转清除杂草
- 远景：达人站在已完成修剪的草坪中央，SEESE 靠在腿边

#### Omini 可直接粘贴的视频生成提示词

```
画面中不得出现任何平台水印、TikTok水印、App界面、账号栏、点赞评论分享按钮、平台Logo、自动字幕、贴纸文字或边框UI。
生成一段10秒9:16竖屏美国社交媒体短视频广告，真实手机手持UGC测评质感。参考图1中的固定白人男性达人在郊区后院草坪（约300平方英尺，午后自然光），使用参考图2中的SEESE无线割草机和参考图3中的产品使用场景作为功能参考。产品只参考Skill A标准参考图，保持青柠绿+黑色配色、D型手柄、可伸缩轴杆、3合1切割头、双21V电池包、SEESE电机外壳Logo一致，不参考原始海报、尺寸图、文字卖点图或对比图，不生成尺寸线，不生成说明文字，不改变产品结构。画面自然真实，像创作者用手机随手拍摄。

00:00-00:02.0，手持中景镜头，达人双手操作SEESE切割头，从割草模式旋转切换到修边模式，动作清晰流畅，展示机械切换结构。
00:02.0-00:04.0，低角度POV跟拍，SEESE修边刀片沿草坪边缘与木质围栏之间推进，切出整齐边界线，草屑向后散落。
00:04.0-00:06.0，POV特写，打草线在草坪角落灌木根部周围快速旋转，清除狭窄区域杂草，画面聚焦切割头与草丛交互。
00:06.0-00:08.0，自拍镜头，达人对镜头露出满意微笑，额头有轻微汗水，身后是已修剪整洁的后院草坪全景。
00:08.0-00:10.0，远景收尾镜头，达人站在草坪中央，SEESE割草机靠在腿边，阳光从侧面照亮整洁的后院，画面温馨有力。

同步美式英语口播："Switch to edger mode for the borders and trimmer mode for tight spots. Three functions, one tool, no cords. This backyard took me twenty minutes."
保留自然环境声、轻微产品声音和真实手机手持感。字幕后期添加，不由视频模型生成文字。
must_keep：保持产品青柠绿+黑色配色、D型手柄形状、可伸缩轴杆、3合1切割头结构、双21V电池包位置、SEESE电机外壳Logo不变，不要增加原始产品不存在的配件。
must_avoid：不要改变产品品类为其他工具，不要虚构不存在的功能，不要增加多余按钮/灯光/接口/装饰，不要改变包装/结构/纹理/视觉比例，不出现原始海报中的文字/图表/箭头/尺寸标注。
```

---

## 10. 独立第 4 段：产品功能展示补位素材（不计入成片时长）

### 口播脚本

不需要同步口播，不展示完整口型表演。

### B-roll 镜头清单（中文）

- 手持特写：达人双手调节伸缩轴杆，拉出或缩回，展示长度可调
- 中景：达人拆卸一块 21V 电池包，展示卡扣结构，再装回
- POV 特写：旋转切割头展示三种模式切换结构与刀片细节
- 远景：SEESE 割草机单独靠在围栏边，阳光照亮青柠绿机身

### Omini 可直接粘贴的视频生成提示词

```
独立第4段：产品功能展示补位素材（不计入成片时长，仅用于后期覆盖前三段中的穿模、穿帮、产品变形、手部异常或嘴型异常画面）

画面中不得出现任何平台水印、TikTok水印、App界面、账号栏、点赞评论分享按钮、平台Logo、自动字幕、贴纸文字或边框UI。
生成一段8-10秒9:16竖屏产品功能展示B-roll，延续前三段正片的郊区后院草坪场景、午后自然光线、达人手部风格（白人男性手部、干净无配饰）、深蓝色Polo衫袖口和真实手机手持UGC质感。产品只参考Skill A标准参考图，保持青柠绿+黑色配色、D型手柄、可伸缩轴杆、3合1切割头、双21V电池包、SEESE电机外壳Logo一致，不新增产品结构，不新增未确认功能，不生成说明文字。

00:00-00:02.0，手持特写镜头，达人双手握住SEESE伸缩轴杆，平稳拉出轴杆约6英寸展示调节功能，然后推回锁定，动作简洁自然。
00:02.0-00:04.0，手持中景镜头，达人右手按下电池包卡扣，取出一个21V电池包，展示卡扣和电池接口，再清脆地装回电机外壳。
00:04.0-00:06.0，POV特写镜头，达人手旋转SEESE切割头，依次经过割草刀片→打草线轴→修边刀片三个位置，动作流畅展示3合1机械结构。
00:06.0-00:08.0，中景产品单独镜头，SEESE割草机靠在木质围栏边，午后阳光照亮青柠绿机身和黑色电机外壳，画面安静自然。
00:08.0-00:10.0，可选远景收尾镜头，SEESE割草机站立在修剪整齐的草坪中央，阳光斜照，作为备用美观特写。

不需要同步口播，不展示完整口型表演。保留自然环境声、轻微产品操作声和真实手机手持感。字幕后期添加，不由视频模型生成文字。
must_keep：保持产品青柠绿+黑色配色、D型手柄形状、可伸缩轴杆、3合1切割头结构、双21V电池包位置、SEESE电机外壳Logo不变，不要增加原始产品不存在的配件。
must_avoid：不要改变产品品类为其他工具，不要虚构不存在的功能，不要增加多余按钮/灯光/接口/装饰，不要改变包装/结构/纹理/视觉比例，不出现原始海报中的文字/图表/箭头/尺寸标注。
```

---

## 11. 成片检查清单

| # | 检查项 | 状态 |
|---|--------|------|
| 1 | 产品外观遵循 Skill A `product_white_bg.png` | — |
| 2 | 功能镜头遵循 Skill A `product_function.png` | — |
| 3 | `product_detail_side.png` 缺失，prompt 中已做保守约束，不推测内部结构 | — |
| 4 | 未将原始海报、尺寸图、对比图或文字卖点图作为直接视频参考 | 通过 |
| 5 | 无夸大声明、保证性结果、医疗/法律/财务承诺或未经证实的对比 | 通过 |
| 6 | 无开箱/包装场景 | 通过 |
| 7 | 未虚构产品形状、隐藏机制、按钮、端口、屏幕、标签、线缆、配件或电子部件 | 通过 |
| 8 | 前 3 秒有明确留存钩子（杂草丛生的草坪边缘痛点画面） | 通过 |
| 9 | 音视频时序与分段脚本匹配 | — |
| 10 | 无平台水印/UI、自动字幕、贴纸、文字叠加、标签或尺寸线 | 通过 |
| 11 | 字幕后期添加 | 通过 |
| 12 | 正片 3 段合计 30 秒 | 通过 |
| 13 | 第 4 段仅为补位 B-roll，不计入成片时长 | 通过 |
| 14 | 每段英语口播 ≤ 30 词（段1: 26词 / 段2: 28词 / 段3: 24词） | 通过 |

---

## 12. 本次视频指纹记录（追加到 video_fingerprint_memory.md）

```markdown
## batch_001 — 2026-06-24

- **SKU**: SEESE Cordless Lawn Mower
- **达人**: 白人男性，37岁，深棕色短发，蓝灰色眼睛，干净胡茬，深蓝色Polo衫，卡其色短裤
- **场景**: 郊区后院草坪约300 sq ft，午后自然光，木质围栏+灌木，无其他人物
- **开头画面**: POV俯拍杂草丛生的草坪边缘与木质围栏边界（痛点切入）
- **叙事角度**: "三台工具的活一台搞定" — 痛点→方案→结果 三段递进
- **镜头结构**: POV痛点俯拍 → 自拍表情 → 产品亮相 → 手持特写 → 中景跟拍割草 → POV功能对比 → 自拍结果微笑 → 远景收尾
- **产品动作顺序**: 旋转展示3合1切割头 → 推割草 → 单手拎起展示轻量 → 切换修边模式 → 修边刀片沿围栏推进 → 打草线清理角落 → 站立收尾
- **收尾画面**: 达人站在修剪整洁的草坪中央，SEESE靠腿边，阳光侧面照明
- **第4段B-roll动作**: 伸缩轴杆调节 → 电池拆卸/装回 → 切割头三种模式旋转 → 产品单独靠围栏静态
- **Hook类型覆盖**: Pain Point / Curiosity / Social Proof / Contradiction / Mistake / Scenario / Challenge / Comparison / Confession / Direct Benefit
```

---

## 13. 视频提交配置 JSON

```json
{
  "batch_id": "batch_001",
  "sku_id": "SEESE Cordless Lawn Mower",
  "product_profile_path": "E:\\test001-1\\product_reference_pack\\SEESE Cordless Lawn Mower\\product_profile.yaml",
  "plan_path": "E:\\test001-1\\product_reference_pack\\SEESE Cordless Lawn Mower\\plan_batch_001.md",
  "video_output_folder": "E:\\视频\\SEESE Cordless Lawn Mower_batch_001",
  "prompt_history_path": "E:\\test001-1\\product_reference_pack\\SEESE Cordless Lawn Mower\\history\\prompt_payloads_batch_001.json",
  "reference_images": {
    "product_white_bg": "E:\\test001-1\\product_reference_pack\\SEESE Cordless Lawn Mower\\images\\product_white_bg.png",
    "product_detail_side": "E:\\test001-1\\product_reference_pack\\SEESE Cordless Lawn Mower\\images\\product_detail_side.png",
    "product_function": "E:\\test001-1\\product_reference_pack\\SEESE Cordless Lawn Mower\\images\\product_function.png"
  },
  "reference_status": {
    "product_white_bg": "ready",
    "product_detail_side": "missing — prompts use conservative fallback phrasing",
    "product_function": "ready"
  },
  "jobs": [
    {
      "job_id": "segment_01",
      "target_filename": "video_001.mp4",
      "duration": "10s",
      "aspect_ratio": "9:16"
    },
    {
      "job_id": "segment_02",
      "target_filename": "video_002.mp4",
      "duration": "10s",
      "aspect_ratio": "9:16"
    },
    {
      "job_id": "segment_03",
      "target_filename": "video_003.mp4",
      "duration": "10s",
      "aspect_ratio": "9:16"
    },
    {
      "job_id": "broll_coverage",
      "target_filename": "video_004.mp4",
      "duration": "8-10s",
      "aspect_ratio": "9:16"
    }
  ],
  "production_defaults": {
    "market": "US",
    "voiceover_language": "American English",
    "planning_language": "Chinese",
    "prompt_language": "Chinese",
    "aspect_ratio": "9:16",
    "visual_style": "realistic phone-shot UGC review",
    "total_duration": "30s (3×10s segments, 4th B-roll not counted)"
  }
}
```

---

## 14. 执行记录

| 步骤 | 状态 | 时间 | 备注 |
|------|------|------|------|
| Skill A 资产读取 | 完成 | 2026-06-24 | product_profile.yaml 完整；product_white_bg.png / product_function.png 就绪；product_detail_side.png 缺失 |
| 历史指纹检查 | 完成 | 2026-06-24 | 无历史记录，首次生成 |
| 方案 Markdown 生成 | 完成 | 2026-06-24 | 保存至 `E:\test001-1\product_reference_pack\SEESE Cordless Lawn Mower\plan_batch_001.md` |
| 参考图上传 jsDelivr | 待执行 | — | 需上传 product_white_bg.png、product_function.png 至 GitHub `fye2552/moyin-images` |
| Omini 视频提交 | 待执行 | — | 4 个 job 待提交：segment_01 / segment_02 / segment_03 / broll_coverage |
| 视频下载 | 待执行 | — | 目标文件夹：`E:\视频\SEESE Cordless Lawn Mower_batch_001` |
| 指纹记忆回写 | 待执行 | — | 写入 `video_fingerprint_memory.md` |
| Prompt 历史保存 | 待执行 | — | 写入 `history/prompt_payloads_batch_001.json` |
*（内容由AI生成，仅供参考）*
