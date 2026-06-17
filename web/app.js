document.addEventListener("DOMContentLoaded", () => {
  // --- Elements ---
  const container = document.getElementById("slidesContainer");
  const slides = Array.from(document.querySelectorAll(".slide"));
  const dots = Array.from(document.querySelectorAll(".dot-btn"));
  const progressBar = document.getElementById("progressBar");
  const prevBtn = document.getElementById("prevBtn");
  const nextBtn = document.getElementById("nextBtn");

  let currentSlideIndex = 0;
  const totalSlides = slides.length;

  // --- Slide Navigation (Scroll & Click & Keys) ---

  // Smooth scroll to slide
  function scrollToSlide(index) {
    if (index < 0 || index >= totalSlides) return;
    slides[index].scrollIntoView({ behavior: "smooth" });
  }

  // Update Indicators (Dots, Progress Bar, Arrows visibility)
  function updateUI(activeIndex) {
    currentSlideIndex = activeIndex;

    // Update active class on slides
    slides.forEach((slide, idx) => {
      if (idx === activeIndex) {
        slide.classList.add("active");
      } else {
        slide.classList.remove("active");
      }
    });

    // Update active dots
    dots.forEach((dot, idx) => {
      if (idx === activeIndex) {
        dot.classList.add("active");
      } else {
        dot.classList.remove("active");
      }
    });

    // Update top progress bar
    const progressPercentage = (activeIndex / (totalSlides - 1)) * 100;
    progressBar.style.width = `${progressPercentage}%`;

    // Update Arrow buttons state
    prevBtn.style.opacity = activeIndex === 0 ? "0.3" : "1";
    prevBtn.style.pointerEvents = activeIndex === 0 ? "none" : "auto";

    nextBtn.style.opacity = activeIndex === totalSlides - 1 ? "0.3" : "1";
    nextBtn.style.pointerEvents =
      activeIndex === totalSlides - 1 ? "none" : "auto";
  }

  // IntersectionObserver to watch which slide is active
  const observerOptions = {
    root: container,
    threshold: 0.5, // trigger when slide is 50% in view
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        const index = slides.indexOf(entry.target);
        updateUI(index);
      }
    });
  }, observerOptions);

  slides.forEach((slide) => observer.observe(slide));

  // Dot navigation click handlers
  dots.forEach((dot) => {
    dot.addEventListener("click", (e) => {
      const slideIndex = parseInt(dot.getAttribute("data-slide"), 10);
      scrollToSlide(slideIndex);
    });
  });

  // Arrow navigation click handlers
  prevBtn.addEventListener("click", () => {
    scrollToSlide(currentSlideIndex - 1);
  });

  nextBtn.addEventListener("click", () => {
    scrollToSlide(currentSlideIndex + 1);
  });

  // Keyboard navigation
  window.addEventListener("keydown", (e) => {
    if (
      e.key === "ArrowDown" ||
      e.key === "ArrowRight" ||
      e.key === "PageDown"
    ) {
      e.preventDefault();
      scrollToSlide(currentSlideIndex + 1);
    } else if (
      e.key === "ArrowUp" ||
      e.key === "ArrowLeft" ||
      e.key === "PageUp"
    ) {
      e.preventDefault();
      scrollToSlide(currentSlideIndex - 1);
    } else if (e.key === " " || e.key === "Spacebar") {
      e.preventDefault();
      scrollToSlide(currentSlideIndex + 1);
    }
  });
});
