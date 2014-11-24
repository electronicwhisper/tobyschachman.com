(function() {
  var cardUnits, maxCardSize, positionCards, setStyle, verticalSpace, videoEl, _fn, _i, _len, _ref,
    __hasProp = {}.hasOwnProperty;

  cardUnits = 18;

  maxCardSize = 420;

  verticalSpace = 4;

  positionCards = function() {
    var cardSize, el, i, numCards, numSpaces, totalUnits, totalWidth, unitSize, x, xIndex, y, yIndex, _i, _len, _ref, _results;
    totalWidth = document.body.clientWidth;
    numCards = 1;
    while (true) {
      numSpaces = numCards + 1;
      totalUnits = numCards * cardUnits + numSpaces;
      unitSize = 1 / totalUnits * totalWidth;
      cardSize = unitSize * cardUnits;
      if (cardSize <= maxCardSize) {
        break;
      } else {
        numCards += 1;
      }
    }
    setStyle("body", {
      fontSize: unitSize
    });
    setStyle(".Card", {
      width: cardSize,
      height: cardSize + verticalSpace * unitSize,
      marginBottom: 0
    });
    setStyle(".CardImage", {
      width: cardSize,
      height: cardSize
    });
    _ref = document.querySelectorAll(".Card");
    _results = [];
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      el = _ref[i];
      el.style.position = "absolute";
      xIndex = i % numCards;
      yIndex = Math.floor(i / numCards);
      x = xIndex * cardSize + (xIndex + 1) * unitSize;
      y = yIndex * cardSize + unitSize + yIndex * verticalSpace * unitSize;
      el.style.left = x + "px";
      _results.push(el.style.top = y + "px");
    }
    return _results;
  };

  setStyle = function(selector, properties) {
    var el, name, value, _i, _len, _ref, _results;
    _ref = document.querySelectorAll(selector);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      el = _ref[_i];
      _results.push((function() {
        var _results1;
        _results1 = [];
        for (name in properties) {
          if (!__hasProp.call(properties, name)) continue;
          value = properties[name];
          _results1.push(el.style[name] = value + "px");
        }
        return _results1;
      })());
    }
    return _results;
  };

  positionCards();

  window.addEventListener("resize", positionCards);

  window.addEventListener("orientationchange", positionCards);

  _ref = document.querySelectorAll("Video");
  _fn = function(videoEl) {
    videoEl.addEventListener("mouseover", function() {
      return videoEl.play();
    });
    return videoEl.addEventListener("mouseout", function() {
      return videoEl.pause();
    });
  };
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    videoEl = _ref[_i];
    _fn(videoEl);
  }

}).call(this);
