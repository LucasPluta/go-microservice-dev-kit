const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = (env, argv) => {
  const isDevelopment = argv.mode === 'development';

  return {
    entry: './src/index.tsx',
    output: {
      path: path.resolve(__dirname, 'build'),
      filename: isDevelopment ? '[name].js' : '[name].[contenthash].js',
      clean: true,
      publicPath: '/',
    },
    resolve: {
      extensions: ['.tsx', '.ts', '.js', '.jsx'],
      extensionAlias: {
        '.js': ['.ts', '.tsx', '.js', '.jsx'],
      },
      fallback: {
        "buffer": false,
        "util": false
      }
    },
    module: {
      rules: [
        {
          test: /\.tsx?$/,
          use: 'ts-loader',
          exclude: /node_modules/,
        },
        {
          test: /\.css$/,
          use: ['style-loader', 'css-loader'],
        },
      ],
    },
    plugins: [
      new HtmlWebpackPlugin({
        template: './public/index.html',
        inject: 'body',
      }),
      new CopyWebpackPlugin({
        patterns: [
          {
            from: 'public',
            to: '.',
            globOptions: {
              ignore: ['**/index.html'],
            },
            noErrorOnMissing: true,
          },
        ],
      }),
    ],
    devServer: {
      static: {
        directory: path.join(__dirname, 'public'),
      },
      compress: true,
      port: 3000,
      hot: true,
      historyApiFallback: true,
      proxy: [
        {
          context: ['/api'],
          target: 'http://localhost:8080',
          changeOrigin: true,
        },
      ],
    },
    devtool: isDevelopment ? 'eval-source-map' : 'source-map',
  };
};