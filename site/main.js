(function () {
  var els = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    els.forEach(function (e) { e.classList.add('in'); });
  } else {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { threshold: 0.12 });
    els.forEach(function (e) { io.observe(e); });
  }
  var hand = document.getElementById('hand');
  var sec = document.getElementById('dongu');
  if (hand && sec && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    var upd = function () {
      var r = sec.getBoundingClientRect();
      var p = Math.min(1, Math.max(0, (innerHeight - r.top) / (r.height + innerHeight)));
      hand.setAttribute('transform', 'rotate(' + (p * 360) + ' 200 200)');
    };
    addEventListener('scroll', upd, { passive: true });
    upd();
  }
})();
