typing = (res, t) ->
	res.robot.adapter.callMethod 'stream-notify-room', res.envelope.room+'/typing', res.robot.alias, t is true

livechatTransferHuman = (res) ->
	setTimeout ->
		res.robot.adapter.callMethod 'livechat:transfer',
			roomId: res.envelope.room
			departmentId: process.env.DEPARTMENT_ID
	, 1000

setUserName = (res, name) ->
	res.robot.adapter.callMethod 'livechat:saveInfo',
		_id: res.envelope.user.id
		name: name
	,
		_id: res.envelope.room

processJson = (res, json) ->
	console.log 'json', json

processBodyJson = (body) ->
	lines = body.split '\n'

	if lines[0].indexOf('json:{') is 0
		parts = lines[0].split('-;-')
		if parts[1]
			lines[0] = parts[1]
		else
			lines = lines.splice(0, 1)

		try
			json = JSON.parse(parts[0].replace('json:', ''))
			processJson(res, json)
		catch e
			console.log 'Invalid JSON'

	return lines.join('\n')

replyWithNaturalDelay = (res, msg, elapsed=0) ->
	keysPerSecond = 100
	maxResponseTimeInSeconds = 3

	if typeof msg isnt 'string'
		cb = msg.callback
		msg = msg.message

	delay = Math.min(Math.max((msg.length / keysPerSecond) * 1000 - elapsed, 0), maxResponseTimeInSeconds * 1000)
	typing res, true
	setTimeout ->
		res.send msg
		typing res, false
		cb?()
	, delay

url = 'https://itsnow.com.br/chat/rocket'

module.exports = (robot) ->

	robot.hear /(.+)/i, (res) ->
		message = res.match[0].replace res.robot.name+' ', ''
		message = message.replace(/^\s+/, '')
		message = message.replace(/\s+&/, '')

		if robot.brain.get('user_without_name_'+res.envelope.room) is true
			if message.indexOf(' ') > -1
				replyWithNaturalDelay res, 'Vamos simplificar, me diga o seu primeiro nome apenas'
				return

			setUserName(res, message)
			res.envelope.user.alias = message
			message = robot.brain.get('last_message_'+res.envelope.room)
			robot.brain.set('user_without_name_'+res.envelope.room, false)

		robot.brain.set('last_message_'+res.envelope.room, message)

		if not res.envelope.user.alias
			robot.brain.set('user_without_name_'+res.envelope.room, true)
			replyWithNaturalDelay res, 'Então, para que possamos começar nossa conversa me diga seu nome'
			return

		typing res, true
		start = Date.now()

		data =
			cod: process.env.ITSNOW_CODE
			nome: res.envelope.user.alias
			email: res.envelope.user.name+'@rocket.chat'
			mensagem: message

		robot.http(url)
			.header('Content-Type', 'application/json')
			.post(JSON.stringify(data)) (err, httpRes, body) ->
				console.log err, body

				if typeof body isnt 'string'
					return

				body = body.replace /\n+$/, ''

				body = processBodyJson body

				end = Date.now()
				diff = end - start

				replyWithNaturalDelay res, body, diff
