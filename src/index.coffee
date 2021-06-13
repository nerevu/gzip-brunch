fs      = require 'fs'
zlib    = require 'zlib'
sysPath = require 'path'

textExts = [/\.html$/, /\.js$/, /\.css$/, /\.svg$/, /\.xml$/]
CONSTANTS = zlib.constants

module.exports = class Gzip
  brunchPlugin: yes

  constructor: (@config) ->
    @options = @config?.plugins?.gzip ? {}
    @options.brotli = @options.brotli ? {}

    @targets = [
      {
        path: @config.paths.public
        ext: /\.html$/
      }
      {
        path: @_joinToPublic @options.paths?.javascript or 'javascripts'
        ext: /\.js$/
      }
      {
        path: @_joinToPublic @options.paths?.stylesheet or 'stylesheets'
        ext: /\.css$/
      }
      {
        path: @_joinToPublic @options.paths?.image or 'images'
        ext: /\.svg$/
      }
      {
        path: @_joinToPublic @options.paths?.root or ''
        ext: /\.ico$/
      }
      {
        path: @_joinToPublic @options.paths?.root or ''
        ext: /\.xml$/
      }
    ]

  onCompile: (generatedFiles) ->
    return unless @config.optimize

    for target in @targets
      break unless fs.existsSync target.path

      fileList = fs.readdirSync target.path
      fileList.forEach (file) =>
        if file.match target.ext
          @_gzip target.path, file

          if @options.brotli.enable
            @_brotli target.path, file

  _compress: (inputPath, outputPath, compressor, options) ->
    input  = fs.createReadStream inputPath
    output = fs.createWriteStream outputPath

    input.pipe(compressor).pipe output

    # Delete the original file generated
    if !!options.removeOriginalFiles and fs.existsSync(inputPath)
      fs.unlinkSync inputPath

    # Rename compressed files to original files
    if !!options.renameFilesToOriginalFiles and fs.existsSync(inputPath)
      fs.renameSync outputPath, inputPath

  _gzip: (path, file) =>
    gzip = zlib.createGzip
      level: @options.quality or zlib.Z_BEST_COMPRESSION

    options =
      removeOriginalFiles: @options.removeOriginalFiles
      renameFilesToOriginalFiles: @options.renameGzipFilesToOriginalFiles

    @_compress "#{path}/#{file}", "#{path}/#{file}.gz", gzip, options

  _brotli: (path, file) =>
    inputPath = "#{path}/#{file}"
    isText = textExts.some (ext) -> file.match ext
    brotliMode = if isText then 'BROTLI_MODE_TEXT' else 'BROTLI_MODE_GENERIC'
    quality = @options.brotli.quality or CONSTANTS.BROTLI_MAX_QUALITY

    brotli = zlib.createBrotliCompress
      params:
        [CONSTANTS.BROTLI_PARAM_MODE]: CONSTANTS[brotliMode]
        [CONSTANTS.BROTLI_PARAM_QUALITY]: quality
        [CONSTANTS.BROTLI_PARAM_SIZE_HINT]: fs.statSync(inputPath).size

    options =
      removeOriginalFiles: @options.removeOriginalFiles
      renameFilesToOriginalFiles: @options.renameBrotliFilesToOriginalFiles

    @_compress inputPath, "#{path}/#{file}.br", brotli, options

  _joinToPublic: (path) =>
    sysPath.join @config.paths.public, path
