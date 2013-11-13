require 'yaml'
require 'pp'
require 'commander/import'

module Jekyll

  class JekDocsStaticFile < StaticFile
    def initialize(site, base, sourceInBaseDir, name, targetInBaseDir)
      @site = site
      @base = base
      @dir = sourceInBaseDir
      @name = name
      @dest = targetInBaseDir
    end

    def destination(dest)
      File.join(dest, @dest, @name)
    end
  end

  class JekDocsPage < Page
    def initialize(site, base, sourceInBaseDir, name, targetInBaseDir, docsConfig)
      @site = site
      @base = base
      @dir = sourceInBaseDir
      @name = name

      self.process(name)
      self.read_yaml(File.join(base, sourceInBaseDir), name)

      permalinkDir = File.basename(name, ".*" )

      if permalinkDir == 'index'
        self.data['permalink'] = "/#{targetInBaseDir}/"
      else
        self.data['permalink'] = "/#{targetInBaseDir}/#{permalinkDir}/"
      end

      self.data['layout'] ||= docsConfig['layout']
      self.data['docsName'] ||= docsConfig['name']
    end

    def permalink
      return nil if self.data.nil? || self.data['permalink'].nil?
      self.data['permalink']
    end
  end

  class JekDocsGenerator < Generator
    safe true

    def generate(site)
      #go through each jekdocs directory
      if site.config['jekdocs']
        for folderPath, values in site.config['jekdocs']

          values['menu'] = []
          values['target'] ||= folderPath
          values['name'] ||= folderPath

          self.processDirectory(
              folderPath,
              values['target'],
              site,
              values,
              values['menu'],
              true
          )
        end
      end
    end

    def processDirectory(sourceInBaseDir, targetInBaseDir, site, config, menu, ignoreDirectoryInMenu=false)
      localConfigPath = File.join(site.source, sourceInBaseDir, '_config.yml')

      if File.exists?(localConfigPath)
        localConfig = YAML.load_file(localConfigPath).merge(config)
      else
        localConfig = config.clone
      end

      if localConfig['copy_only']
        self.blindCopy(sourceInBaseDir, targetInBaseDir, site)
        return
      end

      #add self to menu
      if ignoreDirectoryInMenu
        menuChildren = menu
      else
        currentMenuItem = {
            'title' => localConfig['title'] || self.convertFilenameToTitle(File.basename(sourceInBaseDir)),
            'link' => localConfig['link'] ||  "/#{targetInBaseDir}/",
            'basename' => File.basename(sourceInBaseDir),
            'children' => []
        }

        menu << currentMenuItem

        menuChildren = currentMenuItem['children']
      end



      Dir.foreach(File.join(site.source, sourceInBaseDir)) do |item|
        next if item == '.' or item == '..' or item.start_with?("_")

        if File.directory?(File.join(site.source, sourceInBaseDir, item))
          self.processDirectory(
              File.join(sourceInBaseDir, item),
              File.join(targetInBaseDir, item),
              site,
              config,
              menuChildren
          )
        else
          newPage = JekDocsPage.new(
              site,
              site.source,
              sourceInBaseDir,
              item,
              targetInBaseDir,
              localConfig
          )

          site.pages << newPage

          unless newPage.data['hide_in_menu']
            #add page to menu
            menuChildren << {
                 'title' => newPage.data['menu_title'] || newPage.data['title'] || self.convertFilenameToTitle(File.basename(item, ".*")),
                 'link' => newPage.permalink,
                 'basename' => File.basename(item, ".*")
             }
          end
        end

        menuChildren.sort! do |x,y|
          if localConfig['order']
            if localConfig['order'].include? x['basename'] and localConfig['order'].include? y['basename']
              if localConfig['order'].index(x['basename']) > localConfig['order'].index(y['basename'])
                next 1
              else
                next -1
              end
            elsif localConfig['order'].include? x['basename']
              next -1
            elsif localConfig['order'].include? y['basename']
              next 1
            end
          end

          next x['basename'] <=> y['basename']
        end
      end
    end

    def blindCopy(sourceInBaseDir, targetInBaseDir, site)
      Dir.foreach(File.join(site.source, sourceInBaseDir)) do |item|
        next if item == '.' or item == '..' or item.start_with?("_")

        if File.directory?(File.join(site.source, sourceInBaseDir, item))
          self.blindCopy(
              File.join(sourceInBaseDir, item),
              File.join(targetInBaseDir, item),
              site
          )
        else
          newFile = JekDocsStaticFile.new(
              site,
              site.source,
              sourceInBaseDir,
              item,
              targetInBaseDir
          )

          site.static_files << newFile
        end
      end
    end

    def convertFilenameToTitle(filename)

        filename.

          #separate words with spaces
          gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1 \2').
          gsub(/([a-z\d])([A-Z])/,'\1 \2').
          tr("-", " ").

          downcase.
          capitalize
    end
  end
end
