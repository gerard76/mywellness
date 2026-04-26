document.addEventListener("DOMContentLoaded", function () {
  var form = document.getElementById("sync-form");
  if (!form) return;

  form.addEventListener("submit", function () {
    var btn = document.getElementById("sync-btn");
    btn.classList.add("loading");
    btn.innerHTML = '<span class="btn-spinner"></span>Syncing…';
  });
});
