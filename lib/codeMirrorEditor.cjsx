React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
window._ = _ = require("underscore")
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
    newBranchName = Date.now()
    history = {}
    history[newBranchName] = {ops: []}

    history: history
    shortcutHistory: []
    currentOffset: 0
    currentBranch: newBranchName

  componentDidMount: ->
    window.e2 = @editor = CodeMirror.fromTextArea @refs.editor.getDOMNode(), editorSettings # _(editorSettings).chain().clone().value() #.extend({readOnly: true})
 
    @editor.on 'change', @editorEvent("change")
    @editor.on 'cursorActivity', @editorEvent("cursor")
    @editor.on 'keyHandled', @editorEvent("key")
  
  getDelta: ->
    now = Date.now()
    delta = now - @_lastEvent
    @_lastEvent = now
    return delta
  _lastEvent: 0
  _locked: false
  speed: 2.5
  events: 1
  currentBranch: ->
    @state.history[@state.currentBranch]
  editorEvent: (name) ->
    =>
      return if @_locked == true
      change = @changeHandlers[name].apply(this, arguments)
      change.index = @currentBranch().ops.length
      change.time = @getDelta()
      history = @state.history
      branch = history[@state.currentBranch]
      if change.time < 10 and branch.ops.length > 0
        index = branch.ops.length-1
        changeset = branch.ops[index]
        changeset.push(change)
        offset = @state.currentOffset
      else
        branch.ops.push([change])
        offset = @state.currentOffset+1
      @setState 
        history: history
        currentOffset: offset

  changeHandlers:
    key: (cm, name, event) ->
      type: "key-combo"
      name: name
    change: (cm, change) ->
      type: "text"
      from: _(change.from).clone()
      to: _(change.to).clone()
      text: change.text.slice()
      removed: change.removed.slice()
    cursor: (cm) ->
      selections = cm.listSelections()
      if selections.length == 1 and selections[0].anchor.ch == selections[0].head.ch
        change =
          type: "cursor"
          cursor: selections[0].head
      else
        change = 
          type: "selections"
          selections: selections
      change

  applyOperation: (changes) ->
    for change in changes
      switch change.type
        when "text"
          @editor.replaceRange change.text.join("\n"), change.from, change.to
        when "key-combo"
          @setState shortcutHistory: @state.shortcutHistory.concat [change.name]
        when "cursor"
          @editor.focus()
          @editor.setCursor change.cursor
        when "selections"
          @editor.setSelections change.selections

  play: ->
    branch = @currentBranch()
    if branch.ops.length == 0
      return
    if @state.currentOffset == branch.ops.length
      return

    change = branch.ops[@state.currentOffset]
    @_locked = true
    @applyOperation change
    @_locked = false

    timeOut = switch change[0].type
      when "key-combo" then 0
      else 100
    @setState {currentOffset: @state.currentOffset + 1}, =>
      setTimeout @play, timeOut
    false

  currentOffsetIndicatorPosition: ->
    width = this.refs.timeline?.getDOMNode().getBoundingClientRect().width
    Math.round (@state.currentOffset / (Math.max(0, @currentBranch().ops.length)) * width)

  goTo: (index) ->
    if index == 0
      @editor.doc.setValue ""
      @setState currentOffset: 0
      return
    
    [currentLocation, finish] = [Math.round(@state.currentOffset), Math.round(index)]
    operations = switch
      when currentLocation < finish
        @currentBranch().ops[currentLocation...finish]
      when currentLocation > finish
        _(@currentBranch().ops[finish...currentLocation]).chain().reverse().map(@inverse).value()
      else
        []
    
    if operations.length > 0
      @setState currentOffset: Math.round(index)
      @_locked = true
      for change in operations
        @applyOperation(change)
      @_locked = false
      
  
  invertOperation: (op) ->
    if op.type != "text"
      return op
    newOp = _(op).clone()
    newOp.text = op.removed.slice()
    newOp.removed = op.text.slice()
    newOp.from = _(op.from).clone()
    if newOp.removed.join("*") != ""
      newOp.to = CodeMirror.changeEnd(op)
    else
      newOp.to = newOp.from
    newOp

  inverse: (changes) ->
    _(changes).map(@invertOperation).reverse()
  handleMouseMove: (e) ->
    timelineDimensions = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - timelineDimensions.left)
    @setState playing: false
    if 0 <= mouseLeftOffset <= timelineDimensions.width
      percentOffset = (mouseLeftOffset/timelineDimensions.width)
      zeroIndexedFrame =  percentOffset * (Math.max @currentBranch().ops.length, 0)
      @goTo zeroIndexedFrame

  bars: ->
    bars = []
    for key, val of @state.history
      bars.push 
        name: key
        ops: val.ops
        length: val.ops.length
    bars

  render: ->
    @transferPropsTo <div id="codecap">


    <div className="branch-timeline">
      {@bars().map (bar) =>
        <span className={"bar"+(if bar.name == @state.currentBranch then " active" else "")}>{bar.name} - {bar.length}</span>
      }
    </div>

      <div className={"controls "+(if @state.playing then "playing" else "")}>
        <div onClick={@play}><a className="controls-play" href="#"></a></div>

        <div  onMouseMove={@handleMouseMove} ref="timeline" className="playback-line">
          <span style={{left: @currentOffsetIndicatorPosition()+"px"}} className="playback-location" />
          
        </div>
      </div>
      
      <textarea className="editor-2" ref="editor" />
      <ul id="shortcut-history">
        {@state.shortcutHistory.reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
        <li key="playback">
          Loc: {@state.currentOffset}
          <br/>
          PlayPos:{@currentOffsetIndicatorPosition()}
          <br/>
          HistoryCount:{@currentBranch().ops.length}
        </li>
        
      </ul>
            
      </div>