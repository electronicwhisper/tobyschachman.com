(function() {
  var aspect, el, height, html, maxAspect, maxHeight, maxWidth, parentEl, parentRect, parentStyle, src, width, _i, _len, _ref;

  _ref = document.querySelectorAll(".VideoEmbed");
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    el = _ref[_i];
    parentEl = el.parentNode;
    parentStyle = window.getComputedStyle(parentEl);
    parentRect = parentEl.getBoundingClientRect();
    maxWidth = parentRect.width - parseInt(parentStyle.paddingLeft) - parseInt(parentStyle.paddingRight) - parseInt(parentStyle.borderLeftWidth) - parseInt(parentStyle.borderRightWidth);
    maxHeight = document.body.clientHeight;
    maxAspect = maxWidth / maxHeight;
    src = el.getAttribute("data-src");
    aspect = +el.getAttribute("data-aspect");
    if (aspect > maxAspect) {
      width = maxWidth;
      height = width / aspect;
    } else {
      height = maxHeight;
      width = height * aspect;
    }
    html = "<iframe src=\"" + src + "\" width=\"" + width + "\" height=\"" + height + "\" frameborder=\"0\" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>";
    el.innerHTML = html;
  }

}).call(this);
