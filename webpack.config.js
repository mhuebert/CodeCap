var webpack = require('webpack')
module.exports = {
    entry: [ "webpack-dev-server/client?http://0.0.0.0:3000",
             "webpack/hot/only-dev-server", 
             "./lib/codecap.cjsx"],
    output: {
        path: __dirname,
        filename: "bundle.js"
    },
    plugins: [
      new webpack.HotModuleReplacementPlugin(),
      new webpack.NoErrorsPlugin()
    ],
    resolve: {
      extensions: ['', '.js', 'coffee', '.cjsx']
    },
    module: {
        loaders: [
            { test: /\.cjsx$/, loaders: ['react-hot', 'coffee-loader', 'cjsx-loader']},
            { test: /\.coffee$/, loader: 'coffee' },
            { test: /\.css$/, loader: "style!css" }
        ]
    }
};