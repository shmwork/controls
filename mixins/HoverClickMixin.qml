/// this mixin provides mouse hover and click events handling
BaseMouseMixin {
	property bool clickable: true;
	property bool activeHoverEnabled: false;
	property bool value;
	property bool activeHover: false;

	constructor: {
		this._bindClick(this.clickable)
		this._bindHover(this.enabled)
		this._bindActiveHover(this.activeHoverEnabled)
	}

	///@private
	function _bindClick(value) {
		if (value && !this._hmClickBinder) {
			this._hmClickBinder = new _globals.core.EventBinder(this.element)
			this._hmClickBinder.on('click', _globals.core.createSignalForwarder(this.parent, 'clicked').bind(this))
		}
		if (this._hmClickBinder)
			this._hmClickBinder.enable(value)
	}

	///@private
	function _bindHover(value) {
		if (value && !this._hmHoverBinder) {
			this._initCursorStateTracking()
			this._hmHoverBinder = new _globals.core.EventBinder(this.parent.element)
			if (this._context.backend.capabilities.mouseEnterLeaveSupported) {
				this._hmHoverBinder.on('mouseenter', function() { this._setHovered(this._trueUnlessTouchEvent()) }.bind(this))
				this._hmHoverBinder.on('mouseleave', function() { this._setHovered(false) }.bind(this))
			} else {
				this._hmHoverBinder.on('mouseover', function() { this._setHovered(this._trueUnlessTouchEvent()) }.bind(this))
				this._hmHoverBinder.on('mouseout', function() { this._setHovered(false) }.bind(this))
			}
			this._hmHoverBinder.on('touchstart', this._setTouchEvent.bind(this))
			this._hmHoverBinder.on('mouseup', this._resetTouchEvent.bind(this))
		}
		if (this._hmHoverBinder)
			this._hmHoverBinder.enable(value)
	}

	///@private sets hover unless the cursor is hidden (webOS autohides the cursor, scrolling then fires mouseenter on items passing under it)
	function _setHovered(hover) {
		var g = _globals
		if (hover && g._hoverCursorHidden)
			hover = false
		this.value = hover
		var hoveredItems = g._hoveredItems
		var idx = hoveredItems.indexOf(this)
		if (hover) {
			if (idx < 0)
				hoveredItems.push(this)
		} else if (idx >= 0)
			hoveredItems.splice(idx, 1)
	}

	///@private tracks cursor visibility globally via webOS 'cursorStateChange' and drops hover when the cursor disappears
	function _initCursorStateTracking() {
		var g = _globals
		if (g._hoveredItems)
			return
		g._hoveredItems = []
		g._hoverCursorHidden = false
		if ((g.core.os || '').toLowerCase() !== 'webos') //'cursorStateChange' is a webOS-only event, other platforms may not even have a DOM
			return
		document.addEventListener('cursorStateChange', function(event) {
			g._hoverCursorHidden = !(event.detail && event.detail.visibility)
			if (g._hoverCursorHidden) {
				var hoveredItems = g._hoveredItems.slice()
				g._hoveredItems.length = 0
				for (var i = 0; i < hoveredItems.length; ++i) {
					hoveredItems[i].value = false
					hoveredItems[i].activeHover = false
				}
			}
		})
	}

	///@private
	function _bindActiveHover(value) {
		if (value && !this._hmActiveHoverBinder) {
			this._initCursorStateTracking()
			var g = _globals
			this._hmActiveHoverBinder = new _globals.core.EventBinder(this.parent.element)
			this._hmActiveHoverBinder.on('mouseover', function() { this.activeHover = !g._hoverCursorHidden && this._trueUnlessTouchEvent() }.bind(this))
			this._hmActiveHoverBinder.on('mouseout', function() { this.activeHover = false }.bind(this))
			this._hmActiveHoverBinder.on('touchstart', this._setTouchEvent.bind(this))
			this._hmActiveHoverBinder.on('mouseup', this._resetTouchEvent.bind(this))
		}
		if (this._hmActiveHoverBinder)
		{
			this._hmActiveHoverBinder.enable(value)
		}
	}

	onEnabledChanged: { this._bindHover(value) }
	onClickableChanged: { this._bindClick(value) }
	onActiveHoverEnabledChanged: { this._bindActiveHover(value) }
}
