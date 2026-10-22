const timers = new WeakMap();
document.querySelectorAll("[data-copy]").forEach((button) => {
	button.addEventListener("click", async () => {
		const target = document.getElementById(button.dataset.copy);
		const label = button.querySelector(".copy-label");
		const status = document.getElementById("copy-status");
		try {
			await navigator.clipboard.writeText(target.textContent.trim());
			label.textContent = "Copied";
			status.textContent =
				button.dataset.copy === "install-commands"
					? "Both install commands copied to your clipboard."
					: "Effort command copied to your clipboard.";
			clearTimeout(timers.get(button));
			timers.set(
				button,
				setTimeout(() => {
					label.textContent = "";
				}, 2200),
			);
		} catch {
			const range = document.createRange();
			range.selectNodeContents(target);
			const selection = window.getSelection();
			selection.removeAllRanges();
			selection.addRange(range);
			status.textContent =
				"Select the highlighted command and copy it with your keyboard.";
		}
	});
});
