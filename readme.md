[Releases · astral-sh/uv · GitHub](https://github.com/astral-sh/uv/releases)

### 常见源地址

* 清华： https://pypi.tuna.tsinghua.edu.cn/simple/
* 阿里云： https://mirrors.aliyun.com/pypi/simple/
* 豆瓣： https://pypi.douban.com/simple/
* 中科大： https://pypi.mirrors.ustc.edu.cn/simple/
* 腾讯云： https://mirrors.cloud.tencent.com/pypi/simple/
* 阿里云： https://mirrors.aliyun.com/pypi/simple/
* PYPI： https://pypi.org/simple/

### 查看配置信息

pip config list

conda info


python -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple/ --upgrade pip

conda config --set show_channel_urls yes

uv export --format requirements-txt > requirements.txt
