
for el in document.querySelectorAll(".VideoEmbed")
  parentEl = el.parentNode
  parentStyle = window.getComputedStyle(parentEl)
  parentRect = parentEl.getBoundingClientRect()
  maxWidth = parentRect.width - parseInt(parentStyle.paddingLeft) - parseInt(parentStyle.paddingRight) - parseInt(parentStyle.borderLeftWidth) - parseInt(parentStyle.borderRightWidth)
  maxHeight = document.body.clientHeight

  maxAspect = maxWidth / maxHeight

  src = el.getAttribute("data-src")
  aspect = +el.getAttribute("data-aspect")

  if aspect > maxAspect
    # Video is wider than the max rect
    width = maxWidth
    height = width / aspect
  else
    # Video is narrower than the max rect
    height = maxHeight
    width = height * aspect

  html = """<iframe src="#{src}" width="#{width}" height="#{height}" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>"""

  el.innerHTML = html


