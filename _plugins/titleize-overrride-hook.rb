#!/usr/bin/env ruby
#
# Check for changed posts

module Jekyll
  module Utils
    def self.titleize_slug(slug)
      slug.split(/[_-]/).join(' ')
    end
  end
end

Jekyll::Hooks.register :posts, :post_init do |post|
  # 从文件名提取原始 slug（如 "2025-03-07-hello-world.md" → "hello-world"）
  raw_slug = File.basename(post.relative_path, ".*").split("-")[3..-1].join("-")
  
  # 调用工具方法生成标题
  formatted_title = Jekyll::Utils.titleize_slug(raw_slug)
  
  # 若未手动设置标题，则自动填充
  post.data["title"] ||= formatted_title
end
