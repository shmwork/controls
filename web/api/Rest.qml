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
		var req = api.getList(name, function() {...}, function () { ... })
		req.cancel()
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

	/**aggregates cancelable request handles into one cancelable
	usage:
		var cancel = api.createCancel()
		cancel.add(api.someMethod(...))
		cancel.cancel()
	*/
	function createCancel() {
		var handles = []
		var cancelled = false
		return {
			add: function(handle) {
				if (!handle || !handle.cancel)
					return handle
				if (cancelled) {
					try { handle.cancel() } catch (e) {}
					return handle
				}
				handles.push(handle)
				return handle
			},
			cancel: function() {
				if (cancelled)
					return
				cancelled = true
				var list = handles
				handles = []
				for (var i = 0; i < list.length; i++) {
					try { list[i].cancel() } catch (e) {}
				}
			}
		}
	}

	/// @private calls invokes args, headers and ajax, then processes result
	/// @returns handle with cancel(); cancelled requests do not invoke callback/error
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
		var settled = false

		function settle() {
			if (settled)
				return
			settled = true
			--self.activeRequests
		}

		var handle = apiRequest.ajax({
			method: method || "GET",
			headers: headers,
			contentType: 'application/json',
			settings: {
				timeout: timeout,
			},
			url: url,
			data: data,
			done: function(res) {
				settle()
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
				settle()
				if (error)
					error(res)
				self.error({"url": url, "method": method, "response": res})
			}
		})

		return {
			cancel: function() {
				if (handle && handle.cancel)
					handle.cancel()
				settle()
			}
		}
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
			return method.call(api, arguments)
		}
	}
}
