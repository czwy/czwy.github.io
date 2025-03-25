---
categories:
- Obsidian
date: 2025-03-23 11:25
last_modified_at: 2025-03-25 12:20:28 +0800
mtime: 2025-03-25 12:20:28
tags:
- Obsidian
- Jekyll
title: Obsidian 笔记一键转换发布为 Jekyll 博客
---

Obsidian 是一款功能强大且灵活的知识管理和笔记软件，与 Jekyll 这一轻量级静态博客框架的结合，既能保留 Obsidian 的网状知识关联优势，又能借助 Jekyll 的高效编译能力快速生成标准化博文。
[Obsidian 笔记自动转换为 Jekyll 博客](https://jianyue.tech/posts/obsidian-to-jekyll/)一文介绍了如何把挑选出的 Obsidian 笔记转换成 Jekyll 博文保存在本地的 Jekyll 仓库中，并推送到 github/gitee，并通过webhook 部署到自己的博客服务器上。本文将在此基础上，介绍如何零成本全自动构建一站式内容生产体系。整体流程如下：
1. 用 GitHub Pages 和 Jekyll 搭建静态博客站点
2. 在 Obsidian 笔记中用 md 写笔记
3. 挑选需要作为博文发布的笔记，通过 `quick add`插件的 Macro 脚本把元数据写入博文清单文件
4. 运行 python 脚本，将对应的笔记转换成 Jekyll 博文并保存在本地的 Jekyll 仓库中并推送到 GitHub

## 用 GitHub Pages 搭建静态博客
GitHub 搭建博客最主流的框架是 Hugo、Jekyll、Hexo 。这里选用的是 Jekyll 的Chirpy 主题搭建博客，该主题提供了 chirpy-starter 的模板，对新手非常友好，不需要本地安装 ruby 等 Jekyll 所需要的环境，只需要把博文的 markdown 文件放到 `_posts ` 目录，推送到 GitHub 后会自动执行 `Actions` 任务。详细操作参见官方文档[Getting Started &#124; Chirpy](https://chirpy.cotes.page/posts/getting-started/)

## 图床
在 Obsidian 笔记中用 md 写笔记时会插入图片，通常是在 Obsidian 中配置附件目录，图片保存在本地的附件目录中，但是要把笔记发布到博客中时，这样的处理就需要额外处理图片路径，因此可以选择图床。网络上的图床方案有很多，这里选用 [Cloudflare R2](https://www.cloudflare-cn.com/) 和 [WebP Cloud](https://webp.se/) 搭建免费图床，详细操作参考[从零开始搭建你的免费图床系统（Cloudflare R2 + WebP Cloud）](https://www.pseudoyu.com/zh/2024/06/30/free_image_hosting_system_using_r2_webp_cloud_and_picgo/)一文。

## 挑选笔记写入博文清单
[Obsidian 笔记自动转换为 Jekyll 博客](https://jianyue.tech/posts/obsidian-to-jekyll/)一文介绍了用一个单独的元数据笔记文件记录哪些笔记要转化为博文以及转化过程中需要使用的信息，但并没有描述如何自动化的生成/更新这个元数据笔记文件。我们可以借助 `Quick Add` 插件的 Macro 脚本功能自定义脚本读取笔记信息写到记录博文元数据的清单文件中。这里暂定清单文件名称为 `Posts_to_Jekyll`，并参照 [QuickAdd docs](https://quickadd.obsidian.guide/docs/) 定义一个名为 `WritePostMetadata.js` 的脚本文件。
``` javascript
module.exports = {
    entry: async (params, settings) => {
        const { quickAddApi,app } = params;
        // 获取当前活动的文件
        const activeFile = app.workspace.getActiveFile();
        if (!activeFile) {
            console.error('No active file found.');
            return;
        }
        // 获取当前文件的frontmatter
        const frontmatter = app.metadataCache.getFileCache(activeFile)?.frontmatter
        // 获取当前文件的名称
        const fileName = activeFile.basename; // 获取文件名（不含扩展名）
        if(activeFile.path.indexOf(settings["blogsFolder"]) < 0) return;
        // 获取当前文件的创建时间
        const fileCreationTime = frontmatter.created[0] || new Date(app.workspace.getActiveFile().stat.ctime).toLocaleString().replaceAll("/","-"); // 格式化为 YYYY-MM-DD
        // 获取当前文件的修改时间
        const filemodifyTime = new Date(app.workspace.getActiveFile().stat.mtime).toLocaleString().replaceAll("/","-"); // 格式化为 YYYY-MM-DD
        // 获取当前文件的标签
        const fileTags = frontmatter?.tags || [];
        // 格式化要插入的内容
        const content = `## [[${fileName}]]\n`+
                        `\`\`\`yaml\n`+
                        `title: ${fileName}\n`+
                        `date: ${fileCreationTime}\n`+
                        `mtime: ${filemodifyTime}\n`+
                        `categories: [${fileTags[0]}]\n`+
                        `tags: [${fileTags.filter(item => item != 'blog').join(', ')}]\n`+
                        `\`\`\` \n`;
        // 获取或创建 list 文件
        let listFile = app.vault.getAbstractFileByPath(settings["PostMetadata"]);
        if (!listFile) {
            return `${listFile} is not exist`;
        }
        let metaContent = await app.vault.read(listFile);
        let reg = new RegExp(`(\\#\\# \\[\\[(`+ fileName +`)\\]\\]\n(.+\n){3}mtime:(.+)\n(.+\n){3})`,`g`);
        if(!reg.test(metaContent)){
            // 将内容插入到 list 文件的末尾
            await app.vault.append(listFile, content + '\n');
        }
        else{
            if(RegExp.$4.trim() != filemodifyTime){
                const newContent = metaContent.replaceAll(reg, content);
                await app.vault.modify(listFile,newContent);
            }
        }
    },

    settings: {
        name: "Post_to_Jekyll configuration",
        author: "czwy",
        options: {
            "PostMetadata": {
                type: "dropdown",
                description: "The path of Metadata file which records the article information to be saved to jekyll.",
                defaultValue: "000-Index/Posts_to_Jekyll.md",
                options: app.vault.getAllLoadedFiles().filter(item => item.extension=="md").map(item => item.path),
            },
            "blogsFolder": {
                type: "dropdown",
                description: "blogs folder.",
                defaultValue: "",
                options: app.vault.getAllFolders().map(item => item.path),
            },
        }
    },
};
```
脚本分为 `entry` 和 `settings` 两部分， `entry` 是主要的业务逻辑：读取当前活动（打开的）笔记，读取笔记名称、创建时间、修改时间、标签等元数据，按照既定格式写到`Posts_to_Jekyll`，如果`Posts_to_Jekyll`没有该笔记元数据，则直接添加到末尾，如果已存在该元数据，则比较修改时间，如果修改时间不一致，则修改对应的元数据信息。
`settings` 是接收`Quick Add` 插件 Macros 脚本的设置信息，这里定义了博文类笔记保存的目录 `blogsFolder` 和博文元数据的清单文件 `PostMetadata`，在配置 Macros 时可以根据实际情况自己选择目录和文件。
![WritePostMetadataSetting](https://eb19df4.webp.li/2025/03/WritePostMetadataSetting.png)

## 将 Obsidian 笔记转换为 Jekyll 博文
[Obsidian 笔记自动转换为 Jekyll 博客](https://jianyue.tech/posts/obsidian-to-jekyll/)一文介绍了 Obsidian 笔记转换为 Jekyll 博文时需要处理的一些细节：博文日期、图片处理、链接处理、Callouts 转换为 Prompts，并提供了Python 脚本文件。在我日常笔记应用中会使用到 wiki 链接`[[]]` 和嵌入文本块`![[]]`，因此在原有脚本基础上增加了这两类语法的处理。
### 处理嵌入文本块
嵌入文本块分为全文嵌入和部分嵌入，其语法如下：
``` markdown
![[xxx]]
![[xxx#yyy]]
![[xxx#^yyy]]
```
示例中 `xxx` 是嵌入文本的标题，`#`后边是指定的文本块，如果以 `^` 开头，则是一个文本块，可以理解为一个段落 paragraph，否则表示一个标题及该级标题下所有内容。
全文嵌入的情况，只需通过正则表达式去除 front-matter 信息。
``` python
return re.sub(r'---\n.*?\n---\n','',md_content,flags=re.DOTALL)
```
部分嵌入文本块时，通过 `MarkdownIt` 的 `SyntaxTreeNode` 解析笔记，然后查找类型为 `paragraph` 且以 `^yyy` 结尾的节点，读取该节点内容。
``` python
filtered = list(map(lambda r:r,filter(lambda node: node.type == "paragraph" and ''.join([child.content for child in node.children if child.type == 'text' or child.type == 'inline']).endswith(target), root.children)))
if len(filtered) == 1:
    return '\n'+'\n'.join([child.content for child in filtered[0].children if child.type == 'text' or child.type == 'inline']).strip(target) + '\n'
else:
    return ''
```
部分嵌入标题及该级标题下所有内容时，通过 `MarkdownIt` 的 `SyntaxTreeNode` 解析笔记，然后遍历节点，找到匹配的标题时记录标题层级以及标题的行号作为起始行，然后继续遍历节点，直到找到下一个同级标题，并记录行号，将上一行作为结束行，然后读取起始行和结束行之间的内容。
``` python
start_line = -1
end_line = -1
in_target_section = False

level = -1
in_target_section = False
for node in root.children:
	if node.type == "heading":
		title = ''.join([child.content for child in node.children if child.type == 'text' or child.type == 'inline'])
		if title.strip() == target:
			level = node.tag.replace('h', '')  # 提取标题级别
			in_target_section = True
			start_line = node.map[0]  # 起始行号
			continue
		# 遇到其他二级或更高标题时结束
		if in_target_section and int(level) <= 2:
			end_line = node.map[1] - 1  # 结束行号（前一行的末尾）
			break

if start_line != -1:
	lines = md_content.split('\n')
	end_line = end_line if end_line != -1 else len(lines)
	return '\n'+ '\n'.join(lines[start_line:end_line]).strip()+'\n'
return ""
```
需要注意的是，提取的嵌入式文本可能也嵌入了其他的笔记，因此需要递归执提取。详细的脚本代码见[czwy/obsidian-to-jekyll: A simple python script that converts Obsidian notes to Jekyll themes, and deploy to github pages.](https://github.com/czwy/obsidian-to-jekyll)

### 处理 wiki 链接
首先需要说明的是，这里介绍的 wiki 链接处理思路局限性非常大，只是将`[[]]`的内容转换为 `<a>`标签，链接的文本必须是也作为博客发布的笔记，否则 Github 执行 Action 时会因为找到不链接导致构建失败。处理的脚本如下：
``` python
def process_obsidian_links(self):
	"""format url"""
	def sanitize_slug(string: str) -> str:
		pattern = regex.compile(r'[^\p{M}\p{L}\p{Nd}]+', flags=regex.UNICODE)
		slug = regex.sub(pattern, '-', string.strip())
		slug = regex.sub(r'^-|-$', '', slug, flags=regex.IGNORECASE)
		return slug
	"""replace [[**]] to Tag <a>"""
	def process_title(title, head, alias):
		return f"<a href=\"/posts/{sanitize_slug(title.lower())}/{head or ''}\">{(alias or title).replace('|','')}</a>"
	lines = self.content.splitlines()
	new_lines = []
	for i in range(len(lines)):
		# include obsidian links
		urls = re.finditer(r"\[\[(.*?)(\#.*?)?(\|.*?)?\]\]", lines[i])
		newline = ""
		pos = 0
		for url in urls:
			newline += lines[i][pos:url.start()] + process_title(url.group(1),url.group(2),url.group(3))
			pos = url.end()
		lines[i] = newline + lines[i][pos:]
	self.content = '\n'.join(lines)
```

## 一键发布博文
前面介绍了自动生成博文元数据清单，以及转换博文的 python 脚本，接下来需要让 Obsidian 在更新完博文元数据清单后执行 python 脚本。这里还是定义 Macros 脚本并使用 Node.js 的`child_process`模块执行 python 脚本。
``` javascript
module.exports = {
    entry: async (params, settings) => {
        const { quickAddApi,app,obsidian } = params;

        const { exec } = require('child_process');
        const { promisify } = require('util');
        const fs = require('fs');
        const path = require('path');
        const os = require('os');
        const execAsync = promisify(exec);
        
        try {
            
            let listFile = app.vault.getAbstractFileByPath(settings["PythonScript"]);
            const scriptPath = path.join(app.vault.adapter.basePath,listFile.path);
            const setEncoding = process.platform === 'win32' ? 'chcp 65001 > nul && ' : '';
            
            const execPath = settings["execPath"] || "python";
            const params = settings["parameters"];
            const command = `${setEncoding}"${execPath}" -u "${scriptPath}" ${params}`;
            const { stdout, stderr } = await execAsync(command, {
                timeout: 30000,
                encoding: 'utf8',
                env: {
                    ...process.env,
                    PYTHONIOENCODING: 'utf-8'
                }
            });
           new obsidian.Notice(stdout || stderr || '代码执行完成，无输出',3000);
            return stdout || stderr || '代码执行完成，无输出';
        } catch (error) {
            return `执行错误：${error.message}`;
        }
    },
    settings: {
        name: "Post_to_Jekyll configuration",
        author: "czwy",
        options: {
            "PythonScript": {
                type: "dropdown",
                description: "The path of python script",
                defaultValue: "088-Template/Script/obsidian_to_jekyll.py",
                options: app.vault.getAllLoadedFiles().filter(item => item.extension=="py").map(item => item.path),
            },
            "execPath": {
                type: "text",
                defaultValue: "",
                placeholder: "Placeholder",
                description: "the path of python",
            },
            "parameters": {
                type: "text",
                defaultValue: "-w",
                placeholder: "Placeholder",
                description: " arguments for Script.",
            },
        }
    },
};
```
`entry` 是 Node.js 执行 python 脚本的逻辑， `settings` 用于配置 python 脚本的路径，python程序的路径，以及脚本接收的参数。参数说明如下：
- -w：把笔记转换为Jekyll 博文并保存在本地的 Jekyll 仓库中
- -c：提交修改
- -p：把修改push到GitHub
![Post_to_Jekyll_configuration](https://eb19df4.webp.li/2025/03/Post_to_Jekyll_configuration.png)
至此，主要工作都已完成，接下来就是组合 Macros 脚本，在 `QuickAdd` 的设置界面中添加一个名为 `Post-to-Jekyll`的 macro，然后在 `Post-to-Jekyll`的设置中的User Scripts中依次选用 `WritePostMetadata.js` 和 `execPython.js`，并在脚本中间插入 100ms 的等待。
![Post_to_Jekyll_Macro](https://eb19df4.webp.li/2025/03/Post_to_Jekyll_Macro.png)
当写完博文需要发布时，只需要打开要发布的博文，用 `Ctrl+P` 调出命令列表，执行 `Post-to-Jekyll`命令（也可以为该命令配置快捷键）就可以一键发布博文到 GitHub Pages 了。