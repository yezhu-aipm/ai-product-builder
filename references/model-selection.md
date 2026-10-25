# 国内大模型选型与接入

## 选型要点
| 考虑 | 建议 |
|---|---|
| 接口 | 选**兼容 OpenAI 接口**的，换模型只改配置 |
| 看图 | 要识别拍照、扫描件，就必须选支持看图的模型 |
| 输出 | 统一要求返回 JSON（`response_format=json_object`），解析失败自动重试 |
| 成本 | 先用演示模式（不配密钥）把流程跑通，再接真实模型 |

## 配置项（只写在服务器的 .env 里）
```
LLM_BASE_URL=...
LLM_API_KEY=...
LLM_VISION_MODEL=...   # 读图
LLM_TEXT_MODEL=...     # 写作
```

## 阿里云百炼（通义千问）
- 在百炼控制台的 API Key 页面创建密钥，注意左上角的**地域**。
- 业务空间的密钥（sk-ws 开头）很长，而且 **Base URL 和业务空间绑定**，换了空间要同时换 Base URL。
- 默认业务空间的地址一般是 `https://dashscope.aliyuncs.com/compatible-mode/v1`，具体以控制台显示的为准。

## DeepSeek
- Base URL：`https://api.deepseek.com`；模型名以官方文档为准。

## 连通测试（在服务器上运行）
```
cd /opt/myapp/backend && set -a && . /opt/myapp/.env && set +a && /opt/myapp/venv/bin/python -c "from openai import OpenAI;import os;c=OpenAI(base_url=os.environ['LLM_BASE_URL'],api_key=os.environ['LLM_API_KEY']);print(c.chat.completions.create(model=os.environ['LLM_TEXT_MODEL'],messages=[{'role':'user','content':'只回复四个字：连接成功'}]).choices[0].message.content)"
```
