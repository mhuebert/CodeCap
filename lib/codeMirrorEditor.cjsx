React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
_ = require("underscore")
Recorder = require("./recorder.coffee")

editorSettings = 
  mode: "clojure"
  lineNumbers: false
  lineWrapping: true
  smartIndent: true
  matchBrackets: true
  viewportMargin: Infinity
  theme: 'solarized-light'
  keyMap: 'sublime'
  # editor.setOption("readOnly", true)

module.exports = React.createClass
  
  recorder: Recorder()

  componentDidMount: ->
    @recorder.loadEditor CodeMirror.fromTextArea(@refs.editor.getDOMNode(), editorSettings)

  currentOffsetIndicatorPosition: ->
    width = this.refs.timeline?.getDOMNode().getBoundingClientRect().width
    Math.round (@recorder.location.offset / (Math.max(0, @recorder.branch().ops.length)) * width)
  
  handleMouseMove: (e) ->
    {width, left} = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - left)
    if 0 <= mouseLeftOffset <= width
      percentOffset = (mouseLeftOffset/width)
      zeroIndexedFrame =  percentOffset * (Math.max @recorder.branch().ops.length, 0)
      @recorder.goTo 
        branch: @recorder.location().branch
        offset: zeroIndexedFrame
      @setState lastRendered: Date.now()

  handleBarMove: (bar) ->
    (e) =>
      {width, left} = this.refs[bar.name].getDOMNode().getBoundingClientRect()
      mouseLeftOffset = (e.clientX - left)
      if 0 <= mouseLeftOffset <= width
        percentOffset = (mouseLeftOffset/width)
        zeroIndexedFrame =  percentOffset * (Math.max @recorder.branch(bar.name).ops.length, 0)
        @recorder.goTo 
          branch: bar.name
          offset: zeroIndexedFrame
        @setState lastRendered: Date.now()


  render: ->
    {bars, totalWidth} = @recorder.branches()
    @transferPropsTo <div id="codecap">

    <div className="branch-timeline">
      {bars.map (bar) =>
        barStyle =
          marginLeft: (bar.branch.preOffset/totalWidth)*100+"%"
          width: (bar.branch.ops.length/totalWidth)*100+"%"
        if bar.active == true
          barStyle.backgroundColor = "#bbb"
          barStyle.color = "white"
        <div onMouseMove={@handleBarMove(bar)} 
              style={barStyle} 
              ref={bar.name}
              className={"bar"+(if bar.name == @recorder.location.branch then " active" else "")}>
                {bar.name} - {bar.branch.ops.length}</div>
      }
    </div>

      <div className={"controls "+(if @recorder.playing() then "playing" else "")}>
        <div onClick={@recorder.togglePlay}><a className="controls-play" href="#"></a></div>

        <div  onMouseMove={@handleMouseMove} ref="timeline" className="playback-line">
          <span style={{left: @currentOffsetIndicatorPosition()+"px"}} className="playback-location" />
          
        </div>
      </div>
      
      <textarea className="editor-2" ref="editor" />
      <ul id="shortcut-history">
        {@recorder.shortcutHistory().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
        <li key="playback">
          Loc: {@recorder.location().offset}
          <br/>
          PlayPos:{@currentOffsetIndicatorPosition()}
          <br/>
          HistoryCount:{@recorder.branch().ops.length}
        </li>
        
      </ul>
            
      </div>