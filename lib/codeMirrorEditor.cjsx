React = require("react/addons")
cx = React.addons.classSet
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
_ = require("underscore")
Recorder = require("./recorder.coffee")
monthNames = [ "Jan", "Feb", "Mar", "April", "May", "June",
"July", "Aug", "Sept", "Oct", "Nov", "Dec" ]
zeroFill = (number, width) ->
  width -= number.toString().length
  return new Array(width + ((if /\./.test(number) then 2 else 1))).join("0") + number  if width > 0
  number + "" # always return a string
formatTime = (time) ->
  d = new Date(parseInt(time))
  "#{d.getHours()}:#{zeroFill(d.getMinutes(), 2)}:#{zeroFill(d.getSeconds(), 2)}, #{monthNames[d.getMonth()]} #{d.getDate()}"


module.exports = React.createClass

  getInitialState: ->
    showBranches: true
    recorder: Recorder()
    contextMenu: {visible: false}
    annotation: {}

  componentDidMount: ->
    @state.recorder.initialize
      editor: CodeMirror.fromTextArea(@refs.editor.getDOMNode(), editorSettings)
      onChange: => @setState lastRendered: Date.now()  

  handleMouseMove: (e) ->
    {width, left} = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - left)
    if 0 <= mouseLeftOffset <= width
      @state.recorder.goToPercentOffset @state.recorder.marker(), (mouseLeftOffset/width)

  handleBarMove: (bar) ->
    (e) =>
      {width, left} = this.refs[bar.name].getDOMNode().getBoundingClientRect()
      mouseLeftOffset = (e.clientX - left)
      if 0 <= mouseLeftOffset <= width
        percentOffset = (mouseLeftOffset/width)
        zeroIndexedFrame =  percentOffset * (Math.max @state.recorder.branch(bar.name).ops.length, 0)
        @state.recorder.goToLocation 
          branch: bar.name
          offset: zeroIndexedFrame
  branchToggle: ->
    @setState showBranches: !@state.showBranches
    false
  annotationMenu: (annotation, ref) ->
    (e) =>
      containerBox = this.getDOMNode().getBoundingClientRect()
      this.refs[ref].getDOMNode().getBoundingClientRect()
      {bottom, top, left, width} = this.refs[ref].getDOMNode().getBoundingClientRect()
      document.selection?.empty?() || window.getSelection().removeAllRanges()
      @setState
        contextMenu:
          visible: true
          left: left + width/2 - containerBox.left
          top: bottom - containerBox.top
        annotation: annotation
      , =>
        @refs.annotateTitle.getDOMNode().focus()
      window.onclick = =>
        @setState
          contextMenu:
            visible: false
        window.onclick = null
      e?.preventDefault()
  handleContextMenuKeyDown: (e) ->
    if e.which == 13
      @setState {contextMenu: {visible: false}}
      e.preventDefault()
  handleAnnotationTitleChange: (e) ->
    annotation = @state.annotation
    annotation.title = e.target.value
    @state.recorder.updateAnnotation annotation
    @setState annotation: annotation
  annotate: (reactionReference) -> 
    (e) =>
      annotation = @state.recorder.snapshot()
      setTimeout =>
        @annotationMenu(annotation, "annotation-#{reactionReference}-"+annotation.time)()
      , 20
      e.preventDefault()
  render: ->
    
    {bars, totalWidth, annotations} = @state.recorder.branches()
    bars = [] if !@state.showBranches
    marker = @state.recorder.marker()
    location = @state.recorder.location()

    @transferPropsTo <div id="codecap">

      <div className="codecap-header"  >
        <div className="branch-timeline">
          {bars.map (bar) =>
            minWidth = Math.max(0.03, bar.annotations.length*0.02)
            barStyle =
              marginLeft: (bar.branch.preOffset/totalWidth)*100+"%"
              width: Math.max(minWidth, (bar.branch.ops.length/totalWidth))*100+"%"
            <div onMouseMove={@handleBarMove(bar)} 
                 onClick={@state.recorder.setMarkerHere}
                 onContextMenu={@annotate("timeline")}
                 style={barStyle} 
                 ref={bar.name}
                 key={bar.name}
                 className="bar">
                  
                  {
                    bar.indicators.map (indicator, index) ->
                      <a key={indicator.className+index} className={indicator.className} style={indicator.styles} />
                  }
                  {
                    bar.annotations.map (annotation, index) =>
                      title = annotation.title || formatTime(annotation.time)
                      ref = "annotation-timeline-"+annotation.time
                      <a ref={ref} onContextMenu={@annotationMenu(annotation, ref)} title={title} key={annotation.className+index} className={annotation.className} style={annotation.styles} />
                  }
            </div>
          }
        </div>

          <div className={" controls "+(if @state.recorder.playing() then "playing" else "")}>
            <div onClick={@state.recorder.togglePlay}><a className="controls-play" href="#"></a></div>
            <div onClick={@state.recorder.setMarkerHere} onMouseMove={@handleMouseMove} ref="timeline" className=" playback-line">
              <span style={{left: Math.min(100, ((location.preOffset + location.offset) / (marker.preOffset + marker.offset) * 100))+"%"}} className="playbackLocation" />
            </div>
          </div>
        </div>
        <div className="codemirror-wrap" onMouseEnter={@state.recorder.goToMarker} >
          <textarea onKeyUp={@handleKeyUp} ref="editor" />
        </div>
        <ul id="panel-right" >
          <li><a href="#" onClick={@branchToggle} className="branch-toggle">
          <span /><span /><span />
          </a></li>
          <li><a onClick={@annotate("panel")} className="btn" href="#">+ snapshot</a></li>

          {
            annotations.map (annotation) =>
              ref = "annotation-panel-"+annotation.time

              <li className="annotation">
              <a href="#" ref={ref} onContextMenu={@annotationMenu(annotation, ref)} onClick={=>@state.recorder.playTo(annotation.loc, {transition: 0.1});false}>
                {annotation.title || formatTime(annotation.time)} </a> 
              </li>
          }
            {@state.recorder.shortcutHistory().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
        </ul>
        <div  ref="contextMenu" 
              onKeyDown={@handleContextMenuKeyDown}
              className={cx("context-menu":true, hidden: !@state.contextMenu.visible)}
              style={{left: @state.contextMenu.left, top: @state.contextMenu.top}}
              onClick={(e)->e.stopPropagation()}>
              <input  ref="annotateTitle" 
                      placeholder="Title"
                      onChange={@handleAnnotationTitleChange} value={@state.annotation.title || ""}/></div>
        </div>
editorSettings = 
  mode: "clojure"
  tabSize: 2
  lineNumbers: false
  lineWrapping: true
  smartIndent: true
  matchBrackets: true
  viewportMargin: Infinity
  theme: 'solarized-light'
  keyMap: 'sublime'