React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
_ = require("underscore")
Recorder = require("./recorder.coffee")



module.exports = React.createClass
  
  recorder: Recorder()

  componentDidMount: ->
    @recorder.initialize
      editor: CodeMirror.fromTextArea(@refs.editor.getDOMNode(), editorSettings)
      onChange: => @setState lastRendered: Date.now() 

  handleMouseMove: (e) ->
    {width, left} = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - left)
    if 0 <= mouseLeftOffset <= width
      @recorder.goToMarkerPercentOffset (mouseLeftOffset/width)

  handleBarMove: (bar) ->
    (e) =>
      {width, left} = this.refs[bar.name].getDOMNode().getBoundingClientRect()
      mouseLeftOffset = (e.clientX - left)
      if 0 <= mouseLeftOffset <= width
        percentOffset = (mouseLeftOffset/width)
        zeroIndexedFrame =  percentOffset * (Math.max @recorder.branch(bar.name).ops.length, 0)
        @recorder.goToLocation 
          branch: bar.name
          offset: zeroIndexedFrame

  render: ->
    {bars, totalWidth, annotations} = @recorder.branches()
    marker = @recorder.marker()
    location = @recorder.location()
    bars = []

    @transferPropsTo <div id="codecap">
      <div className="codecap-header"  onMouseLeave={@recorder.goToMarker} onMouseEnter={@handleMouseEnter}>
        <div className="branch-timeline">
          {bars.map (bar) =>
            minWidth = Math.max(0.03, bar.annotations.length*0.02)
            barStyle =
              marginLeft: (bar.branch.preOffset/totalWidth)*100+"%"
              width: Math.max(minWidth, (bar.branch.ops.length/totalWidth))*100+"%"
            <div onMouseMove={@handleBarMove(bar)} 
                 onClick={@recorder.setMarkerHere}
                 onContextMenu={@recorder.snapshot}
                 style={barStyle} 
                 ref={bar.name}
                 key={bar.name}
                 className="bar">
                  {
                    bar.annotations.concat(bar.indicators).map (indicator, index) ->
                      <span key={indicator.className+index} className={indicator.className} style={indicator.styles} />
                  }
            </div>
          }
        </div>

          <div className={"controls "+(if @recorder.playing() then "playing" else "")}>
            <div onClick={@recorder.togglePlay}><a className="controls-play" href="#"></a></div>
            <div onClick={@recorder.setMarkerHere} onMouseMove={@handleMouseMove} ref="timeline" className=" playback-line">
              <span style={{left: Math.min(100, ((location.preOffset + location.offset) / (marker.preOffset + marker.offset) * 100))+"%"}} className="playbackLocation" />
            </div>
          </div>
        </div>
        <textarea onKeyUp={@handleKeyUp} ref="editor" />
        <ul id="panel-right" >
        <li><a onClick={@recorder.snapshot} className="btn" href="#">+ snapshot</a></li>
        {
          annotations.map (annotation) =>
            <li><a href="#" onClick={=>@recorder.playTo(annotation.loc);false}>
              {Math.round(annotation.loc.offset)}</a>
            </li>
        }
          {@recorder.shortcutHistory().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
          
        </ul>
              
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