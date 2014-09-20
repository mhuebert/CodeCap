React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
window._ = _ = require("underscore")
{Vector} = require("immutable")
Draggable = require('react-draggable')

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
  getInitialState: ->
    history: Vector()
    shortcutHistory: Vector()
    playbackLocation: 0

  componentDidMount: ->
    window.cm = @editor = CodeMirror.fromTextArea @refs.editor.getDOMNode(), editorSettings
    window.e2 = @editor2 = CodeMirror.fromTextArea @refs.editor2.getDOMNode(), _(editorSettings).chain().clone().extend({readOnly: true}).value()

    @editor.on 'changes', @handleChanges
    @editor.on 'cursorActivity', @handleCursorActivity
    @editor.on 'keyHandled', @handleKey

  handleKey: (cm, name, event) ->
    history = @state.history.concat [
      type: "key-combo"
      name: name
    ]
    @setState history: history
  handleChanges: (cm, changes) ->
    history =  @state.history.concat [
      type: "text"
      time: Date.now()
      changes: changes 
    ]
    @setState history: history

  
  handleCursorActivity: (cm) ->
    selections = cm.listSelections()
    if selections.length == 1 and selections[0].anchor.ch == selections[0].head.ch
      change =
        type: "cursor"
        cursor: selections[0].head
        time: Date.now()
    else
      change = 
        type: "selections"
        selections: selections
        time: Date.now()
    history = @state.history.concat [change]
    @setState history: history

  applyChange: (change) ->
    switch change.type
      when "text"
        for change in change.changes
          @editor2.replaceRange change.text.join("\n"), change.from, change.to
      when "key-combo"
        @setState shortcutHistory: @state.shortcutHistory.concat [change.name]
      when "cursor"
        @editor2.focus()
        @editor2.setCursor change.cursor
      when "selections"
        @editor2.setSelections change.selections
  
  play: ->
    if @state.playing or @state.history.length == 0
      @setState {playing: false}
      return
    
    if @state.playbackLocation == @state.history.length-1 
      startLocation = 0
      @goTo 0
    else 
      startLocation = @state.playbackLocation+1

    playFrom = (frameIndex) =>
      if frameIndex == @state.history.length or !@state.playing
        @setState {playing: false}
        return
      change = @state.history.get(frameIndex)
      @applyChange change
      timeOut = switch change.type
        when "key-combo" then 0
        else 30
      @setState {playbackLocation: frameIndex}, ->
        setTimeout ->
          playFrom(frameIndex+1)
        , timeOut
    @setState {playing: true}, ->
      playFrom(Math.round startLocation)
    false

  playbackLocationIndicatorPosition: ->
    width = this.refs.playbackLine?.getDOMNode().getBoundingClientRect().width
    offset = switch
      when Math.ceil(@state.playbackLocation) == @state.history.length-1
        width - 3
      else
        (@state.playbackLocation / (@state.history.length) * width)

  goTo: (index) ->
    @editor2.setValue ""
    for change in @state.history.toJS()[0..index]
      @applyChange(change)
    @setState playbackLocation: index
  
  handleMouseMove: (e) ->
    playbackLine = this.refs.playbackLine.getDOMNode()
    rect = playbackLine.getBoundingClientRect()
    offset = (e.clientX - rect.left)
    if 0 <= offset <= rect.width
      @goTo (offset/rect.width) * @state.history.length

  render: ->
    @transferPropsTo <div>
        
        <textarea className="editor-1" ref="editor" />
        <div id="codecap-preview">
          <div className={"controls "+(if @state.playing then "playing" else "")}>
            <div onClick={@play}><a className="controls-play" href="#"></a></div>
            <div  onMouseMove={@handleMouseMove} ref="playbackLine" className="playback-line">
              <span style={{left: @playbackLocationIndicatorPosition()+"px"}} className="playback-location" />
            </div>
          </div>

          
          <textarea className="editor-2" ref="editor2" />
          <ul id="shortcut-history">
            {@state.shortcutHistory.toJS().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
            <li key="playback">{@state.playbackLocation}, {@playbackLocationIndicatorPosition()}</li>
            <li key="history-length">{@state.history.length}</li>
          </ul>
            
        </div>
      </div>