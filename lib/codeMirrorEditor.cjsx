React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
window._ = _ = require("underscore")
{Vector} = require("immutable")
Draggable = require('react-draggable')

editorSettings = 
  mode: "clojure"
  lineNumbers: true
  lineWrapping: true
  smartIndent: true
  matchBrackets: true
  theme: 'solarized-light'
  keyMap: 'sublime'

module.exports = React.createClass
  getInitialState: ->
    history: Vector()
    shortcutHistory: Vector()
    playbackLocation: 0

  componentDidMount: ->
    window.cm = @editor = CodeMirror.fromTextArea @refs.editor.getDOMNode(), editorSettings
    @editor2 = CodeMirror.fromTextArea @refs.editor2.getDOMNode(), editorSettings

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
    history =  @state.history.concat changes.map (change) -> 
      change.time = Date.now()
      change.type = "text"
      change
    @setState history: history

  handleCursorActivity: (cm) ->
    history = @state.history.concat [
      type: "selections"
      selections: cm.listSelections()
      time: Date.now()
    ]
    @setState history: history

  applyChange: (change) ->
    switch change.type
      when "text"
        @editor2.replaceRange change.text.join("\n"), change.from, change.to
      when "key-combo"
        @setState shortcutHistory: @state.shortcutHistory.concat [change.name]
      when "selections"
        @editor2.setSelections change.selections
  play: ->
    startLocation = @state.playbackLocation+1
    for change, index in @state.history.toJS().slice(startLocation)
      do (change, index) =>
        setTimeout =>
          @setState playbackLocation: index+startLocation
          @applyChange(change)
        , (index * 500)
    false

  # backwards: ->
  #   for change, in
  playbackLocationIndicatorPosition: ->
    (@state.playbackLocation / (@state.history.length-1)) * 400

  goTo: (index) ->
    @editor2.setValue ""
    for change in @state.history.toJS()[0..index]
      @applyChange(change)
    @setState playbackLocation: index
  
  handleDrag: (event, ui) ->
    left = ui.position.left
    indicator = this.refs.playbackIndicator.getDOMNode()
    if left < 0
      indicator.style.left = 0
    if left > 410
      indicator.style.left = 410
    if 0 < left < 411
      @goTo (left/410) * @state.history.length
  handleMouseMove: (e) ->
    node = this.refs.playbackLine.getDOMNode()
    offset = parseInt(e.clientX - node.getBoundingClientRect().left)
    @goTo (offset/410) * @state.history.length
  render: ->
    @transferPropsTo <div>
        
        <textarea className="editor-1" ref="editor" />
        <div id="codecap-preview">
          <ul className="codecap-controls">
            <li onClick={@play}><a href="#">Play</a></li>
            
            <li  onMouseMove={@handleMouseMove} ref="playbackLine" className="playback-line">
              <span style={{left: @playbackLocationIndicatorPosition()+"px"}} className="playback-location" />
            </li>
            
          </ul>
          <textarea className="editor-2" ref="editor2" />
          <ul id="shortcut-history">{@state.shortcutHistory.toJS().reverse().slice(0,5).map((shortcut)-><li>{shortcut}</li>)}</ul>
        </div>
      </div>