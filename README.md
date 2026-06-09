# Qwen Image LoRA for AutoDL

这是一个面向 AutoDL 的 Qwen Image 家族 LoRA 训练模板。使用者只需要上传自己的数据集，修改 `config/default.yaml`，然后在 AutoDL 上一键完成环境准备、模型下载和训练。

本仓库不包含任何训练数据集、私有图片、私有 caption 或模型权重。

## 适合做什么

- 在 AutoDL 云 GPU 上训练 Qwen Image LoRA
- 使用本地 fp8 transformer 单文件，降低显存占用
- 独立调整模型、tokenizer、text encoder、VAE 路径
- 通过三档 LoRA rank 快速切换训练规模
- 使用默认 EMA、自动采样和定期保存配置

## 目录说明

```text
config/default.yaml        默认训练配置，主要修改这里
scripts/cloud_setup.sh     AutoDL 一键安装依赖、下载模型并开始训练
run.py                     训练入口，环境准备好后可直接调用
datasets/                  放自己的训练数据，仓库默认不提交数据集
```

## 参考配置

AutoDL 官网：[https://www.autodl.com/](https://www.autodl.com/)

![AutoDL 参考配置](AutoDL.webp)

| 项目 | 配置 |
| --- | --- |
| 镜像 | PyTorch 2.7.0 / Python 3.12 / Ubuntu 22.04 |
| CUDA | 12.8 |
| GPU | RTX PRO 6000 96GB * 1 |
| CPU | 25 vCPU Intel(R) Xeon(R) Platinum 8470Q |
| 内存 | 120GB |
| 硬盘 | 系统盘 30GB，数据盘免费 50GB，付费 0GB |

## AutoDL 快速开始

### 1. 上传代码

把本仓库上传到 AutoDL 的数据盘，例如：

```bash
/root/autodl-tmp/ai-toolkit
```

如果你是通过压缩包上传，请确保解压后能看到：

```bash
/root/autodl-tmp/ai-toolkit/run.py
/root/autodl-tmp/ai-toolkit/config/default.yaml
/root/autodl-tmp/ai-toolkit/scripts/cloud_setup.sh
```

### 2. 准备数据集

把图片和同名 caption 文本放到：

```bash
/root/autodl-tmp/ai-toolkit/datasets/default
```

示例结构：

```text
datasets/default/
  001.jpg
  001.txt
  002.png
  002.txt
```

caption 文件使用 `.txt`，文件名需要和图片一致。

### 3. 修改触发词

打开 `config/default.yaml`，修改：

```yaml
trigger_word: "触发词"
```

例如：

```yaml
trigger_word: "my style"
```

训练时，配置里的 `[trigger]` 会被替换成这里的触发词。

### 4. 一键运行

在 AutoDL 终端中执行：

```bash
cd /root/autodl-tmp/ai-toolkit
bash scripts/cloud_setup.sh
```

这个脚本会依次完成：

1. 检查代码目录
2. 安装系统依赖
3. 安装 Python 依赖
4. 下载默认 Qwen Image fp8 transformer
5. 缓存 tokenizer、text encoder、VAE
6. 自动执行训练命令

脚本最后会自动运行：

```bash
python3 run.py config/default.yaml
```

所以通常不需要再手动执行第二遍。

## 只训练，不重新安装

如果依赖和模型已经准备好，可以直接运行：

```bash
python3 run.py config/default.yaml
```

注意不是 `python run default.yaml`，正确入口是 `run.py`，并且要传入配置路径。

## 修改模型路径

主要修改 `config/default.yaml` 里的 `model` 段。

默认配置：

```yaml
model:
  name_or_path: "/root/autodl-tmp/models/qwen_image_2512_fp8_e4m3fn.safetensors"
  tokenizer_name_or_path: "Qwen/Qwen-Image"
  tokenizer_subfolder: "tokenizer"
  text_encoder_name_or_path: "Qwen/Qwen-Image"
  text_encoder_subfolder: "text_encoder"
  vae_name_or_path: "Qwen/Qwen-Image"
  vae_subfolder: "vae"
```

如果你只替换 transformer 单文件，改：

```yaml
name_or_path: "/root/autodl-tmp/models/your_qwen_image_model.safetensors"
```

如果你要替换一整套 Qwen Image base 组件，可以同时改：

```yaml
tokenizer_name_or_path: "你的模型仓库或本地路径"
text_encoder_name_or_path: "你的模型仓库或本地路径"
vae_name_or_path: "你的模型仓库或本地路径"
```

如果路径已经直接指向组件目录，把对应 subfolder 改为：

```yaml
tokenizer_subfolder: null
text_encoder_subfolder: null
vae_subfolder: null
```

如果你使用 `scripts/cloud_setup.sh` 自动下载模型，也需要同步修改脚本里的：

```bash
MODEL_FILE=...
MODEL_URL=...
```

否则脚本仍会下载默认模型文件。

## LoRA rank 档位

`config/default.yaml` 默认使用中档：

```yaml
linear: 16
linear_alpha: 16
conv: 16
conv_alpha: 16
```

推荐三档：

```text
低档：8
中档：16，默认
高档：32
```

切换时建议四个值保持一致。

## 采样配置

默认有 6 条 sample prompt，其中 5 条带 `[trigger]`，1 条不带触发词，用于观察 LoRA 对触发词和普通提示词的影响。

位置：

```yaml
sample:
  samples:
    - prompt: "[trigger], ..."
```

可以按自己的风格或任务类型修改。

## 输出位置

默认训练输出在：

```bash
/root/autodl-tmp/output
```

LoRA 权重、日志和 sample 图片都会写入这里。

## LoRA 训练效果

下面是 LoRA 训练完成后使用个人 ComfyUI 工作流的图片展示：

![LoRA 训练效果：Giyu Tomioka](Giyu%20Tomioka.png)

正面提示词：

```text
ydd style, Tomioka Giyu, full body dynamic composition. He is leaping into the air in a highly dynamic combat stance, twisting his body in mid-air, gripping a chilling blue Nichirin sword with both hands, executing the Water Breathing technique. His black medium-length hair and iconic asymmetrical tortoiseshell pattern haori are fluttering fiercely in the wind. Surrounded by massive water vortex effects intertwined with dense and light ink splashes. Traditional Chinese ink painting style, strong motion blur, ink splashing, xuan paper texture, extreme details, 8k ultra-high definition.
```

负面提示词：

```text
(worst quality, low quality:1.4),
(bad hands, missing fingers, extra fingers, fused fingers, too many fingers:1.4),
(deformed hands, malformed hands, missing hand, floating hand:1.3),
(bad anatomy, bad proportions, extra limbs, missing limbs:1.3),
(deformed face, asymmetrical eyes, cross-eyed, blurry face, distorted features:1.3),
text, watermark, signature
```

随机种子：

```text
318036859179089
```

## 常见问题

### 仓库为什么没有数据集？

为了方便公开分发，也避免误传私人数据，本仓库默认不提交 `datasets/` 下的训练数据。请自行上传图片和 caption 到 AutoDL。
