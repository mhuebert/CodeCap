require("codemirror/lib/codemirror.css")
require("../style.css")

React = require("react")
CodeMirror = require("codemirror")
Editor = require("./codeMirrorEditor")

Root = React.createClass
  render: ->
    <div>
      <Editor />
    </div>

React.renderComponent(<Root />, document.body)
