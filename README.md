# Xcode文件模版的配置和使用

* 资料来源：[**创建自定义模版**](https://juejin.cn/post/6974702344021737485)

* 在系统中前往文件夹（或者快捷键：`shift+command+G`）输入✍️

  ```
  /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/File Templates/iOS/Source/
  ```

* 同步代码模版（后缀名为`xctemplate`的文件夹）至以上的系统指定文件夹（或者直接运行`autoSetup.command`必要时需要`chmod+x`）

* 注意事项：系统下的那个文件不能直接修改（因为MacOS升级了安全策略）。修改文件模版下的完成后，复制到系统下覆盖掉就可以马上生效
