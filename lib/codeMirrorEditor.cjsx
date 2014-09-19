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
    history =  @state.history.concat [
      type: "text"
      time: Date.now()
      changes: changes 
    ]
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
        for change in change.changes
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
        , (index * 20)
    false

  playbackLocationIndicatorPosition: ->
    @state.playbackLocation / (@state.history.length) * 100

  goTo: (index) ->
    @editor2.setValue ""
    for change in @state.history.toJS()[0..index]
      @applyChange(change)
    @setState playbackLocation: index
  
  handleMouseMove: (e) ->
    playbackLine = this.refs.playbackLine.getDOMNode()
    rect = playbackLine.getBoundingClientRect()
    offset = (e.clientX - rect.left)
    @goTo (offset/rect.width) * @state.history.length

  render: ->
    @transferPropsTo <div>
        
        <textarea className="editor-1" ref="editor" />
        <div id="codecap-preview">
          <div className="controls">
            <div onClick={@play}><a className="controls-play" href="#"></a></div>
            <div  onMouseMove={@handleMouseMove} ref="playbackLine" className="playback-line">
              <span style={{left: @playbackLocationIndicatorPosition()+"%"}} className="playback-location" />
            </div>
          </div>

          
          <textarea className="editor-2" ref="editor2" />
          <ul id="shortcut-history">
            {@state.shortcutHistory.toJS().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}</ul>
        </div>
      </div>