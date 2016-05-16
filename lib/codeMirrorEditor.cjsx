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

  reset: ->
    if confirm("Are you sure? You will lose all your data...")
      @setState(@getInitialState())
      @reInit()  

  reInit: ->
    self = this

    @state.editor.setValue("")
    @state.recorder.initialize
      editor: @state.editor
      triggerRender: (callback=->) ->
        self.setState {lastRendered: Date.now()}, callback 

  componentDidMount: ->
    self = this
    @setState editor: CodeMirror.fromTextArea(@refs.editor.getDOMNode(), editorSettings)
    @state.recorder.initialize
      editor: @state.editor
      triggerRender: (callback=->) -> 
        self.setState {lastRendered: Date.now()}, callback

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
          type: "annotation"
        annotation: annotation
      , =>
        @refs.annotateTitle.getDOMNode().focus()
      e?.preventDefault()
      window.onclick = =>
        @setState
          contextMenu:
            visible: false
        window.onclick = null
      
  handleContextMenuKeyDown: (e) ->
    if e.which == 13
      @setState {contextMenu: {visible: false}}
      e.preventDefault()
  handleAnnotationTitleChange: (e) ->
    annotation = @state.annotation
    annotation.title = e.target.value
    @state.recorder.updateAnnotation annotation
    @setState annotation: annotation
  annotate: (uiLocation) -> 
    (e) =>
      @state.recorder.annotate (annotation) =>
        @annotationMenu(annotation, "annotation-#{uiLocation}-"+annotation.time)()
        @state.recorder.setMarkerHere()
      e.preventDefault()
  saveJSON: (e) ->
    uriContent = "data:application/octet-stream," + encodeURIComponent(JSON.stringify(@state.recorder.history()))
    e.target.href = uriContent
  loadJSON: (e) ->
    reader = new FileReader()
    
    reader.onloadend = (what) =>
      history = JSON.parse(reader.result)
      @setState {recorder: Recorder(history: history)}
      @reInit()
    
    reader.readAsText(e.target.files[0])
  setGlobalHover: (name) ->
    (e) =>
      @setState hovering: name
  render: ->
    
    {bars, totalWidth, annotations} = @state.recorder.branches()
    bars = [] if !@state.showBranches
    marker = @state.recorder.marker()
    location = @state.recorder.location()

    @transferPropsTo <div id="codecap">
      <ul id="panel-right" >
        <li><a href="#" onClick={@branchToggle} className="hidden branch-toggle">
        <span /><span /><span />
        </a></li>
        <li>
        <div className="btn btn-dark width-33" style={position: "relative", overflow: "hidden"}>
          Open
           <input type="file" onChange={@loadJSON} className="hiddenx" ref="upload"
             style={position: "absolute", display: "block", background: "pink", left: 0, right: 0, top: -100, bottom: 0, opacity: 0} />
        </div>
        <a className="btn btn-dark width-33" download="history.json" onClick={@saveJSON} href="#">Save</a>
        <a className="btn btn-dark width-33" onClick={@reset} href="#">Clear</a>
        </li>
        <span style={display: "block", boxShadow: "0 0 5px rgba(0,0,0,0.2)"} >  
        <li>
        
        <a onClick={@annotate("panel")} style={marginBottom: 0} className="btn" href="#">+ Snapshot</a></li>

        {
          annotations.map (annotation) =>
            <li >
              <Annotation ref={"annotation-panel-"+annotation.time} 
                          key={annotation.time}
                          annotation={annotation}
                          parent={this}>{annotation.title || formatTime(annotation.time)}</Annotation> 
            </li>
        }
        </span>
          {@state.recorder.shortcutHistory().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
      </ul>
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
                      <Annotation ref={"annotation-timeline-"+annotation.time} 
                                  key={annotation.time} 
                                  annotation={annotation} 
                                  parent={this}
                                  styles={annotation.styles} /> 
                  }
            </div>
          }
        </div>

          <div className={" controls "+(if @state.recorder.playing() then "playing" else "")}>
            <div onClick={@state.recorder.togglePlay}><a className="hidden controls-play" href="#"></a></div>
            <div onClick={@state.recorder.setMarkerHere} onMouseMove={@handleMouseMove} ref="timeline" className=" playback-line">
              <span style={{left: Math.min(100, ((location.preOffset + location.offset) / (marker.preOffset + marker.offset) * 100))+"%"}} className="playbackLocation" />
            </div>
          </div>
        </div>
        <div>
        
        <div className="codemirror-wrap" onMouseEnter={@state.recorder.goToMarker} >
          <textarea onKeyUp={@handleKeyUp} ref="editor" />
        </div>
        
        <div  ref="contextMenu" 
              onKeyDown={@handleContextMenuKeyDown}
              className={cx("context-menu":true, hidden: !@state.contextMenu.visible)}
              style={{left: @state.contextMenu.left, top: @state.contextMenu.top}}
              onClick={(e)->e.stopPropagation()}>
              <input  ref="annotateTitle" 
                      placeholder="Title"
                      onChange={@handleAnnotationTitleChange} value={@state.annotation.title || ""}/></div>
        <div style={marginTop: 10, textAlign: "right"}>              
        
        
        
        
        
        </div>
        </div>
        </div>

Annotation = React.createClass
  displayName: "annotation"
  render: ->
    {parent, annotation, ref, styles} = @props
    styles = styles || {}
    recorder = parent.state.recorder
    <a  href="#"
        style={styles}
        className={cx({active: recorder.locationsEqual(recorder.marker(), annotation.loc),annotation:true, hovering: parent.state.hovering == "annotation-"+annotation.time})}
        onMouseEnter={parent.setGlobalHover("annotation-"+annotation.time)}
        onMouseLeave={parent.setGlobalHover(null)}
        onContextMenu={parent.annotationMenu(annotation, ref)} 
        onClick={=>parent.state.recorder.playTo(annotation.loc, {transition: 2});false}>
        {@props.children}</a>


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