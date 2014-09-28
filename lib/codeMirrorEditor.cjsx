React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
window._ = _ = require("underscore")
Draggable = require('react-draggable')
Recorder = require("./recorder.coffee")

editorSettings = 
  mode: "clojure"
  lineNumbers: false
  lineWrapping: true
  smartIndent: true
  matchBrackets: true
  theme: 'solarized-light'
  keyMap: 'sublime'
  # editor.setOption("readOnly", true)

module.exports = React.createClass
  recorder: Recorder()
  componentDidMount: ->
    window.e2 = @editor = CodeMirror.fromTextArea @refs.editor.getDOMNode(), editorSettings # _(editorSettings).chain().clone().value() #.extend({readOnly: true})
    @recorder.loadEditor(@editor)

  currentOffsetIndicatorPosition: ->
    width = this.refs.timeline?.getDOMNode().getBoundingClientRect().width
    Math.round (@recorder.currentOffset / (Math.max(0, @recorder.currentBranch().ops.length)) * width)
  
  handleMouseMove: (e) ->
    timelineDimensions = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - timelineDimensions.left)
    @setState playing: false
    if 0 <= mouseLeftOffset <= timelineDimensions.width
      percentOffset = (mouseLeftOffset/timelineDimensions.width)
      zeroIndexedFrame =  percentOffset * (Math.max @recorder.currentBranch().ops.length, 0)
      @recorder.goTo zeroIndexedFrame

  render: ->
    @transferPropsTo <div id="codecap">

    <div className="branch-timeline">
      {@recorder.bars().map (bar) =>
        <span className={"bar"+(if bar.name == @recorder.currentBranch() then " active" else "")}>{bar.name} - {bar.length}</span>
      }
    </div>

      <div className={"controls "+(if @recorder.playing then "playing" else "")}>
        <div onClick={@recorder.togglePlay}><a className="controls-play" href="#"></a></div>

        <div  onMouseMove={@handleMouseMove} ref="timeline" className="playback-line">
          <span style={{left: @currentOffsetIndicatorPosition()+"px"}} className="playback-location" />
          
        </div>
      </div>
      
      <textarea className="editor-2" ref="editor" />
      <ul id="shortcut-history">
        {@recorder.shortcutHistory.reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
        <li key="playback">
          Loc: {@recorder.currentOffset}
          <br/>
          PlayPos:{@currentOffsetIndicatorPosition()}
          <br/>
          HistoryCount:{@recorder.currentBranch().ops.length}
        </li>
        
      </ul>
            
      </div>