require("codemirror/lib/codemirror.css")
require("../styles.styl")

React = require("react")
Editor = require("./codeMirrorEditor")

Root = React.createClass
  render: ->
      <Editor />

React.renderComponent(<Root />, document.body)
