/* =========================================
   MOR PANCHAYAT WEBSITE
   Main JavaScript
========================================= */


/* =========================================
   LANGUAGE
========================================= */

let currentLanguage = "en";


function setLanguage(language) {

    currentLanguage = language;


    /*
        Find every element that contains
        English + Hindi translations.
    */

    const elements =
        document.querySelectorAll(
            "[data-en][data-hi]"
        );


    elements.forEach((element) => {

        const text =
            language === "hi"
                ? element.getAttribute("data-hi")
                : element.getAttribute("data-en");


        if (text) {

            element.textContent = text;

        }

    });


    /*
        Update HTML language
    */

    document.documentElement.lang =
        language === "hi"
            ? "hi"
            : "en";


    /*
        Update page title
    */

    if (language === "hi") {

        document.title =
            "Mor Panchayat - आधिकारिक ऐप";

    } else {

        document.title =
            "Mor Panchayat - Official App";

    }


    /*
        Update language buttons
    */

    const englishButton =
        document.getElementById(
            "navEnglish"
        );

    const hindiButton =
        document.getElementById(
            "navHindi"
        );


    if (englishButton && hindiButton) {

        englishButton.classList.toggle(
            "active",
            language === "en"
        );

        hindiButton.classList.toggle(
            "active",
            language === "hi"
        );

    }


    /*
        Save language preference
    */

    try {

        localStorage.setItem(
            "morPanchayatLanguage",
            language
        );

    } catch (error) {

        console.log(
            "Language preference could not be saved."
        );

    }

}



/* =========================================
   LOAD SAVED LANGUAGE
========================================= */

document.addEventListener(
    "DOMContentLoaded",
    () => {

        let savedLanguage = "en";


        try {

            savedLanguage =
                localStorage.getItem(
                    "morPanchayatLanguage"
                ) || "en";

        } catch (error) {

            savedLanguage = "en";

        }


        setLanguage(savedLanguage);


        initializeScrollAnimations();

    }
);



/* =========================================
   SCROLL ANIMATIONS
========================================= */

function initializeScrollAnimations() {

    const animatedElements =
        document.querySelectorAll(
            ".feature-card, .history-card, .release-card, .install-card"
        );


    /*
        Initial state
    */

    animatedElements.forEach(
        (element) => {

            element.style.opacity = "0";

            element.style.transform =
                "translateY(25px)";

            element.style.transition =
                "opacity 0.6s ease, transform 0.6s ease";

        }
    );


    /*
        Intersection Observer
    */

    const observer =
        new IntersectionObserver(
            (entries) => {

                entries.forEach(
                    (entry) => {

                        if (
                            entry.isIntersecting
                        ) {

                            entry.target.style.opacity =
                                "1";

                            entry.target.style.transform =
                                "translateY(0)";

                            observer.unobserve(
                                entry.target
                            );

                        }

                    }
                );

            },
            {
                threshold: 0.12
            }
        );


    animatedElements.forEach(
        (element) => {

            observer.observe(element);

        }
    );

}



/* =========================================
   NAVBAR ACTIVE LINK
========================================= */

const sections =
    document.querySelectorAll(
        "section[id]"
    );


const navLinks =
    document.querySelectorAll(
        ".nav-links a"
    );


window.addEventListener(
    "scroll",
    () => {

        let currentSection = "";


        sections.forEach(
            (section) => {

                const sectionTop =
                    section.offsetTop - 120;


                if (
                    window.scrollY >=
                    sectionTop
                ) {

                    currentSection =
                        section.getAttribute("id");

                }

            }
        );


        navLinks.forEach(
            (link) => {

                link.style.color = "";


                if (
                    link.getAttribute("href") ===
                    `#${currentSection}`
                ) {

                    link.style.color =
                        "#176B4D";

                }

            }
        );

    }
);



/* =========================================
   DOWNLOAD TRACKING
========================================= */

const downloadLinks =
    document.querySelectorAll(
        'a[download]'
    );


downloadLinks.forEach(
    (link) => {

        link.addEventListener(
            "click",
            () => {

                console.log(
                    "Mor Panchayat APK download started."
                );

            }
        );

    }
);



/* =========================================
   SMOOTH SCROLL
========================================= */

document.querySelectorAll(
    'a[href^="#"]'
).forEach(
    (link) => {

        link.addEventListener(
            "click",
            function (event) {

                const targetId =
                    this.getAttribute("href");


                if (
                    targetId === "#"
                ) {

                    return;

                }


                const target =
                    document.querySelector(
                        targetId
                    );


                if (target) {

                    event.preventDefault();


                    target.scrollIntoView({
                        behavior: "smooth",
                        block: "start"
                    });

                }

            }
        );

    }
);



/* =========================================
   DOWNLOAD BUTTON FEEDBACK
========================================= */

downloadLinks.forEach(
    (button) => {

        button.addEventListener(
            "click",
            () => {

                const originalHTML =
                    button.innerHTML;


                /*
                    Small visual feedback.
                */

                setTimeout(
                    () => {

                        button.innerHTML =
                            originalHTML;

                    },
                    1500
                );

            }
        );

    }
);



/* =========================================
   PREVENT ACCIDENTAL DOUBLE CLICK
========================================= */

let downloadLocked = false;


downloadLinks.forEach(
    (button) => {

        button.addEventListener(
            "click",
            () => {

                if (downloadLocked) {

                    return;

                }


                downloadLocked = true;


                setTimeout(
                    () => {

                        downloadLocked = false;

                    },
                    2000
                );

            }
        );

    }
);
