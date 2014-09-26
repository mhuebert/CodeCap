React = require("react/addons")
CodeMirror = require("codemirror")
require("codemirror/keymap/sublime.js")
require("codemirror/mode/clojure/clojure.js")
window._ = _ = require("underscore")
Immutable = require("immutable")
{Vector} = Immutable
Draggable = require('react-draggable')

logChange = (change) ->
  console.log "#{change.from.line}:#{change.from.ch} to #{change.to.line}:#{change.to.ch} - #{change.date}"
  change

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
    history: Immutable.fromJS {"/": {operations: []}}
    shortcutHistory: Vector()
    currentOffset: 0
    currentBranch: "/"

  componentDidMount: ->
    window.e2 = @editor = CodeMirror.fromTextArea @refs.editor.getDOMNode(), editorSettings # _(editorSettings).chain().clone().value() #.extend({readOnly: true})
 
    @editor.on 'changes', @editorEvent("changes")
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

  editorEvent: (name) ->
    =>
      return if @_locked == true
      change = @changeHandlers[name].apply(this, arguments)
      change.index = @state.history.get(@state.currentBranch).get("operations").length
      change.time = @getDelta()
      history = @state.history.updateIn [@state.currentBranch, "operations"], (vec) -> vec.concat([change])
      @setState 
        history: history
        currentOffset: @state.currentOffset + 1

  changeHandlers:
    key: (cm, name, event) ->
      type: "key-combo"
      name: name
    changes: (cm, changes) ->
      if changes.length > 1
        console.log changes.map (c) -> "#{c.from.ch}:#{c.to.ch}"
      type: "text"
      changes: changes.map (change, index) ->
        from: _(change.from).clone()
        to: _(change.to).clone()
        text: change.text.slice()
        removed: change.removed.slice()
        date: "#{index} - #{Date.now()}"
        index: index
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

  applyOperation: (change) ->
    console.log "Operation ##{change.index}"
    switch change.type
      when "text"
        if change.changes.length > 1
          console.log change.changes.map (c) -> "#{c.from.ch}:#{c.to.ch}   #{c.text.join("")}  -  #{c.removed.join("")}"
        else
          console.log change.changes[0]
        for c in change.changes
          # if change.changes.length > 1
          # console.log "Operation...#{c.index}, t: #{c.text.join("")}, r: #{c.removed.join("")}", -((c.from.line * 1000) + c.from.ch)
          # console.log "replaceRange", c.text.join("\\n"), c.from, c.to
          @editor.replaceRange c.text.join("\n"), c.from, c.to
      when "key-combo"
        @setState shortcutHistory: @state.shortcutHistory.concat [change.name]
      when "cursor"
        @editor.focus()
        @editor.setCursor change.cursor
      when "selections"
        @editor.setSelections change.selections
  
  

  # play: ->
  #   if @state.playing or @state.history.get("/").length == 0
  #     @setState {playing: false}
  #     return
    
  #   if @state.currentOffset == @state.history.get("/").length-1 
  #     startLocation = 0
  #     @goTo 0
  #   else 
  #     startLocation = @state.currentOffset+1

  #   playFrom = (frameIndex) =>
  #     if frameIndex == @state.history.get("/").length or !@state.playing
  #       @setState {playing: false}
  #       return
  #     change = @state.history.get("/").get(frameIndex)
  #     @applyOperation change
  #     timeOut = switch change.type
  #       when "key-combo" then 0
  #       else 30
  #     @setState {currentOffset: frameIndex}, ->
  #       setTimeout ->
  #         playFrom(frameIndex+1)
  #       , Math.min((change.time/@speed), 500)
  #   @setState {playing: true}, ->
  #     playFrom(Math.round startLocation)
  #   false

  currentOffsetIndicatorPosition: ->
    width = this.refs.timeline?.getDOMNode().getBoundingClientRect().width
    Math.round (@state.currentOffset / (Math.max(0, @state.history.get("/").get("operations").length)) * width)

  goTo: (index) ->
    
    [currentLocation, finish] = [Math.round(@state.currentOffset), Math.round(index)]
    currentOperations = @state.history.get(@state.currentBranch).get("operations").toJS()
    operations = switch
      when currentLocation < finish
        console.log "moving from #{currentLocation} to #{finish}"
        currentOperations[currentLocation...finish]
      when currentLocation > finish
        console.log "moving from #{currentLocation} to #{finish} (inverse)"
        _(currentOperations[finish...currentLocation]).chain().reverse().map(@inverse).value()
      else
        []
    
    if operations.length > 0
      @setState currentOffset: Math.round(index)
      @_locked = true
      for change in operations
        @applyOperation(change)
      @_locked = false
      
  
  invertOperation: (op) ->
    newOp = _(op).clone()
    newOp.text = op.removed.slice()
    newOp.removed = op.text.slice()
    newOp.from = _(op.from).clone()
    if newOp.removed.join("") != ""
      newOp.to = CodeMirror.changeEnd(op)
    else
      newOp.to = newOp.from
    # if op.text.join("") != ""
    #   newOp.to = CodeMirror.changeEnd(op)
    # else
    #   newOp.to = _(op.to).clone()
    newOp

  inverse: (changeset) ->
    if changeset.type != "text"
      return changeset
    c = _(changeset).clone()
    c.changes = _(changeset.changes).chain()
                        .map(@invertOperation)
                        .sortBy (op) -> op.from.ch
                        .sortBy (op) -> op.from.line
                        .value()
    c
  handleMouseMove: (e) ->
    timelineDimensions = this.refs.timeline.getDOMNode().getBoundingClientRect()
    mouseLeftOffset = (e.clientX - timelineDimensions.left)
    @setState playing: false
    if 0 <= mouseLeftOffset <= timelineDimensions.width
      percentOffset = (mouseLeftOffset/timelineDimensions.width)
      zeroIndexedFrame =  percentOffset * (Math.max @state.history.get(@state.currentBranch).get("operations").length, 0)
      @goTo zeroIndexedFrame

  bars: ->
    bars = []
    for key, val of @state.history.toJS()
      bars.push 
        name: key
        operations: val.operations
        length: val.operations.length
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
        {@state.shortcutHistory.toJS().reverse().slice(0,5).map((shortcut, i)-><li key={i}>{shortcut}</li>)}
        <li key="playback">
          Loc: {@state.currentOffset}
          <br/>
          PlayPos:{@currentOffsetIndicatorPosition()}
          <br/>
          HistoryCount:{@state.history.get(@state.currentBranch).get("operations").length}
        </li>
        
      </ul>
            
      </div>