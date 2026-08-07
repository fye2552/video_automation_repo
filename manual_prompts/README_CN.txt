手动提示词直连视频

使用位置：
1. 把提示词文本放进 pending 文件夹。
2. 文件名必须与 local_products 下的产品文件夹名称一致。
   示例：local_products\3_stage_professional_knife_sharpener
   对应：manual_prompts\pending\3_stage_professional_knife_sharpener.txt
3. 一个 txt 文件默认提交一个视频。
4. 若同一产品需要生成多个独立视频，用单独一行 === 分隔多个提示词块。
   每个非空块都会创建一个独立的视频任务。
5. 双击项目根目录的 start_and_run_manual_prompts.bat。
6. 成功提交的 txt 会被移动到 submitted。

注意：
- 启动器只读取 manual_prompts\pending，不读取旧的中文目录。
- 只会处理存在同名产品文件夹的 txt；其他产品不会上传或提交。
- 图片仍由现有 local-product-upload-github 流程上传；视频由已有 worker 下载到 video_output。
