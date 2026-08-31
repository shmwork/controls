/**
	Root component for REST API declaration.
	Normally Rest component contains one or more Method instances.
	<pre>
		Rest {
			id: api;
			baseUrl: "https://example.com/v1";

			function headers(headers) { headers.token = 'secret'; }

			Method { name: "getList"; path: "list/{name}"; }
		}
		//in js:
		api.getList(name, function() {...}, function () { ... })
	</pre>
*/


Object {
	Request { id: apiRequest; } ///< Request object used for ajax requests

	property string baseUrl; ///< base url for all requests

	signal error; ///< all errors signalled here
	signal internetConnectionLost; ///< some platforms signal when internet connection lost, see onError
	property int activeRequests; ///< number of currently running requests.
	property bool blockRequests; ///< if true block any api requests

	constructor: {
		this._methods = {}
	}

	onError(url, method, response): {
		if ((typeof window !== 'undefined' && !window.navigator.onLine) || response && response.target && response.target.status === 0 && response.target.response === "") {
			this.internetConnectionLost({ "url": url, "method": method, "response": response })
		}
	}

	/// args function allows to override arguments for all methods, e.g. adding session token
	function args(args) {
		return args
	}

	/// headers function allows to override headers for all methods, e.g. adding session token
	function headers(headers) {
	}

	/**bag of abortable requests belonging to one logical operation
	usage:
		var cancel = api.createCancel()
		cancel.add(api.call(...)) // or any handle with abort()
		cancel.abort()
	*/
	function createCancel() {
		var handles = []
		return {
			aborted: false,
			add: function(handle) {
				if (!handle || !handle.abort)
					return handle
				if (this.aborted) {
					try { handle.abort() } catch (e) {}
					return handle
				}
				handles.push(handle)
				return handle
			},
			abort: function() {
				if (this.aborted)
					return
				this.aborted = true
				var list = handles
				handles = []
				for (var i = 0; i < list.length; i++) {
					try { list[i].abort() } catch (e) {}
				}
			}
		}
	}

	/// @private calls invokes args, headers and ajax, then processes result
	function _call(name, callback, error, method, data, head, timeout) {
		var headers = head || {}

		if (data) {
			data = this.args(data)
			headers["Content-Type"] = "application/json"
		}

		var newHeaders = this.headers(headers)
		if (newHeaders !== undefined)
			headers = newHeaders

		++this.activeRequests
		var url = name
		var self = this

		return apiRequest.ajax({
			method: method || "GET",
			headers: headers,
			contentType: 'application/json',
			settings: {
				timeout: timeout,
			},
			url: url,
			data: data,
			done: function(res) {
				--self.activeRequests
				if (res.target && res.target.status >= 400) {
					log("Error in request", res)
					if (error)
						error(res)
					self.error({"url": url, "method": method, "response": res})
					return
				}

				var text = res.target.responseText
				if (!text) {
					callback("")
					return
				}
				var res
				try {
					res = JSON.parse(text)
				} catch (e) {
					res = text
				}
				callback(res)
			},
			error: function(res) {
				--self.activeRequests
				if (res && res.type === "abort")
					return
				if (error)
					error(res)
				self.error({"url": url, "method": method, "response": res})
			}
		})
	}

	/// @internal top-level call implementation
	function call(name, callback, error, method, data, head, timeout) {
		if (this.blockRequests) return
		if (name.indexOf('://') < 0) {
			var baseUrl = this.baseUrl
			if (baseUrl[baseUrl.length - 1] === '/' || name[0] === '/')
				name = baseUrl + name
			else
				name = baseUrl + '/' + name
		}
		return this._call(name, callback, error, method, JSON.stringify(data), head, timeout)
	}

	/// @private method registration
	function _registerMethod(name, method) {
		if (!name)
			return

		var api = this
		this[name] = function() {
			method.call(api, arguments)
		}
	}
}
