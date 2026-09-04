/* =========================================================
   MOR PANCHAYAT WEBSITE
   Dynamic GitHub Releases + UI
========================================================= */


/* =========================================================
   CONFIGURATION
========================================================= */

const GITHUB_OWNER = "Anshu101com";
const GITHUB_REPO = "mor-panchayat";

const GITHUB_RELEASES_API =
    `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases?per_page=100`;

const GITHUB_REPOSITORY_URL =
    `https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}`;

const GITHUB_RELEASES_URL =
    `${GITHUB_REPOSITORY_URL}/releases`;


/* =========================================================
   GLOBAL STATE
========================================================= */

let githubReleases = [];
let currentLanguage =
    localStorage.getItem("morPanchayatLanguage") || "en";


/* =========================================================
   TRANSLATIONS
========================================================= */

const translations = {

    en: {
        releaseLoading: "Loading releases from GitHub...",
        releaseError: "Unable to load release history.",
        releaseErrorDescription:
            "GitHub could not be reached right now. Please try again later.",
        retry: "Try Again",

        latestRelease: "Latest Release",
        latestBuild: "Latest Beta Build",
        latestBuildDescription:
            "Get the latest Android build and experience the newest improvements.",

        downloadLatest: "Download Latest APK",
        downloadNow: "Download Now",
        downloadVersion: "Download Version",

        viewReleases: "View Releases",
        viewGithubRelease: "View Release",
        apkUnavailable: "APK unavailable",

        latestVersion: "Latest Version",
        previousVersions: "Previous Versions",

        beta: "Beta",
        preRelease: "Pre-Release",
        stable: "Stable",

        releaseHistory: "RELEASE HISTORY",
        previousVersionsTitle: "Previous versions.",
        releaseHistoryDescription:
            "Download an earlier version whenever you need it. Each release keeps its own APK download link.",

        noReleases: "No releases found.",
        noReleasesDescription:
            "Create a GitHub Release with an APK asset to display it here.",

        currentBuild: "Current Build",

        version: "Version",
        platform: "Platform",
        releaseType: "Release Type",

        android: "Android",

        released: "Released",
        downloads: "downloads",

        releaseNotes: "Release Notes",
        noReleaseNotes: "No release notes were provided.",

        githubReleases: "GitHub Releases"
    },

    hi: {
        releaseLoading: "GitHub से रिलीज़ लोड हो रही हैं...",
        releaseError: "रिलीज़ इतिहास लोड नहीं हो सका।",
        releaseErrorDescription:
            "अभी GitHub से कनेक्ट नहीं हो पाया। कृपया बाद में दोबारा प्रयास करें।",
        retry: "दोबारा प्रयास करें",

        latestRelease: "नवीनतम रिलीज़",
        latestBuild: "नवीनतम बीटा बिल्ड",
        latestBuildDescription:
            "नवीनतम Android बिल्ड डाउनलोड करें और नए सुधारों का अनुभव करें।",

        downloadLatest: "नवीनतम APK डाउनलोड करें",
        downloadNow: "अभी डाउनलोड करें",
        downloadVersion: "वर्ज़न डाउनलोड करें",

        viewReleases: "रिलीज़ देखें",
        viewGithubRelease: "रिलीज़ देखें",
        apkUnavailable: "APK उपलब्ध नहीं है",

        latestVersion: "नवीनतम वर्ज़न",
        previousVersions: "पिछले वर्ज़न",

        beta: "बीटा",
        preRelease: "प्री-रिलीज़",
        stable: "स्टेबल",

        releaseHistory: "रिलीज़ इतिहास",
        previousVersionsTitle: "पिछले वर्ज़न।",
        releaseHistoryDescription:
            "जब भी ज़रूरत हो किसी पुराने वर्ज़न को डाउनलोड करें। प्रत्येक रिलीज़ का अपना APK डाउनलोड लिंक है।",

        noReleases: "कोई रिलीज़ नहीं मिली।",
        noReleasesDescription:
            "इसे यहाँ दिखाने के लिए GitHub पर APK के साथ एक Release बनाएं।",

        currentBuild: "वर्तमान बिल्ड",

        version: "वर्ज़न",
        platform: "प्लेटफ़ॉर्म",
        releaseType: "रिलीज़ प्रकार",

        android: "Android",

        released: "जारी किया गया",
        downloads: "डाउनलोड",

        releaseNotes: "रिलीज़ नोट्स",
        noReleaseNotes: "कोई रिलीज़ नोट उपलब्ध नहीं है।",

        githubReleases: "GitHub रिलीज़"
    }

};


/* =========================================================
   HELPER
========================================================= */

function t(key) {
    return (
        translations[currentLanguage]?.[key] ||
        translations.en[key] ||
        key
    );
}


function escapeHTML(value) {

    if (value === null || value === undefined) {
        return "";
    }

    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}


/* =========================================================
   VERSION HELPERS
========================================================= */

function cleanVersion(version) {

    if (!version) {
        return "Unknown";
    }

    return version
        .replace(/^v/i, "")
        .trim();
}


function versionNumber(version) {

    const match =
        String(version || "")
            .match(/(\d+)\.(\d+)\.(\d+)/);

    if (!match) {
        return [0, 0, 0];
    }

    return [
        Number(match[1]),
        Number(match[2]),
        Number(match[3])
    ];
}


function compareVersions(a, b) {

    const av = versionNumber(a.tag_name);
    const bv = versionNumber(b.tag_name);

    for (let i = 0; i < 3; i++) {

        if (av[i] !== bv[i]) {
            return bv[i] - av[i];
        }

    }

    return (
        new Date(b.published_at || b.created_at || 0) -
        new Date(a.published_at || a.created_at || 0)
    );
}


/* =========================================================
   DATE FORMAT
========================================================= */

function formatDate(dateString) {

    if (!dateString) {
        return "";
    }

    const date =
        new Date(dateString);

    if (Number.isNaN(date.getTime())) {
        return "";
    }

    return date.toLocaleDateString(
        currentLanguage === "hi"
            ? "hi-IN"
            : "en-IN",
        {
            day: "numeric",
            month: "short",
            year: "numeric"
        }
    );
}


/* =========================================================
   FILE SIZE
========================================================= */

function formatFileSize(bytes) {

    if (!bytes || bytes <= 0) {
        return "";
    }

    const units = [
        "B",
        "KB",
        "MB",
        "GB"
    ];

    let size = bytes;
    let index = 0;

    while (
        size >= 1024 &&
        index < units.length - 1
    ) {

        size /= 1024;
        index++;

    }

    return `${size.toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
}


/* =========================================================
   FIND APK
========================================================= */

function findAPK(release) {

    if (!Array.isArray(release.assets)) {
        return null;
    }

    /*
       Prefer APK files.
       This means the website does NOT depend on
       a specific APK filename.
    */

    const apk =
        release.assets.find(asset =>
            asset.name
                .toLowerCase()
                .endsWith(".apk")
        );

    return apk || null;
}


/* =========================================================
   RELEASE TYPE
========================================================= */

function getReleaseType(release) {

    if (release.prerelease) {
        return t("preRelease");
    }

    return t("stable");
}


/* =========================================================
   RELEASE DESCRIPTION
========================================================= */

function getReleaseDescription(release) {

    if (!release.body) {
        return t("noReleaseNotes");
    }

    const text =
        release.body
            .replace(/[#*_>`~-]/g, "")
            .replace(/\r?\n+/g, " ")
            .trim();

    if (!text) {
        return t("noReleaseNotes");
    }

    if (text.length > 180) {
        return text.substring(0, 177) + "...";
    }

    return text;
}


/* =========================================================
   GITHUB RELEASE CARD
========================================================= */

function createReleaseCard(
    release,
    index
) {

    const version =
        release.tag_name ||
        release.name ||
        "Unknown";

    const apk =
        findAPK(release);

    const isLatest =
        index === 0;

    const date =
        formatDate(
            release.published_at ||
            release.created_at
        );

    const type =
        getReleaseType(release);

    const description =
        getReleaseDescription(release);

    const apkSize =
        apk
            ? formatFileSize(apk.size)
            : "";

    const downloadCount =
        apk &&
        typeof apk.download_count === "number"
            ? apk.download_count
            : null;


    const apkButton =
        apk
            ? `
                <a
                    class="release-download"
                    href="${escapeHTML(apk.browser_download_url)}"
                    download
                    target="_blank"
                    rel="noopener"
                >
                    ⬇
                    ${escapeHTML(t("downloadVersion"))}
                </a>
            `
            : `
                <a
                    class="release-download"
                    href="${escapeHTML(release.html_url)}"
                    target="_blank"
                    rel="noopener"
                >
                    ↗
                    ${escapeHTML(t("viewGithubRelease"))}
                </a>
            `;


    return `
        <article class="release-item reveal">

            <div class="release-version-icon">
                ${isLatest ? "🚀" : "📦"}
            </div>

            <div class="release-main">

                <h3>

                    ${escapeHTML(version)}

                    ${
                        isLatest
                            ? `
                                <span class="release-status">
                                    ${escapeHTML(t("latestRelease"))}
                                </span>
                              `
                            : ""
                    }

                </h3>

                <p>

                    ${escapeHTML(type)}

                    ${
                        date
                            ? ` · ${escapeHTML(t("released"))} ${escapeHTML(date)}`
                            : ""
                    }

                    ${
                        apkSize
                            ? ` · ${escapeHTML(apkSize)}`
                            : ""
                    }

                    ${
                        downloadCount !== null
                            ? ` · ${downloadCount.toLocaleString()} ${escapeHTML(t("downloads"))}`
                            : ""
                    }

                </p>

                ${
                    description
                        ? `
                            <p class="release-description">
                                ${escapeHTML(description)}
                            </p>
                          `
                        : ""
                }

            </div>

            ${apkButton}

        </article>
    `;
}


/* =========================================================
   LOADING STATE
========================================================= */

function showReleaseLoading() {

    const container =
        document.getElementById("releaseList");

    if (!container) {
        return;
    }

    container.innerHTML = `

        <div class="release-state">

            <div class="release-loader"></div>

            <strong>
                ${escapeHTML(t("releaseLoading"))}
            </strong>

            <span>
                GitHub
            </span>

        </div>

    `;
}


/* =========================================================
   ERROR STATE
========================================================= */

function showReleaseError() {

    const container =
        document.getElementById("releaseList");

    if (!container) {
        return;
    }

    container.innerHTML = `

        <div class="release-state release-error">

            <div class="release-state-icon">
                ⚠️
            </div>

            <strong>
                ${escapeHTML(t("releaseError"))}
            </strong>

            <span>
                ${escapeHTML(t("releaseErrorDescription"))}
            </span>

            <button
                class="secondary-button"
                id="retryReleases"
                type="button"
            >
                ↻
                ${escapeHTML(t("retry"))}
            </button>

        </div>

    `;


    const retryButton =
        document.getElementById(
            "retryReleases"
        );

    if (retryButton) {

        retryButton.addEventListener(
            "click",
            loadGitHubReleases
        );

    }
}


/* =========================================================
   EMPTY STATE
========================================================= */

function showReleaseEmpty() {

    const container =
        document.getElementById("releaseList");

    if (!container) {
        return;
    }

    container.innerHTML = `

        <div class="release-state">

            <div class="release-state-icon">
                📦
            </div>

            <strong>
                ${escapeHTML(t("noReleases"))}
            </strong>

            <span>
                ${escapeHTML(t("noReleasesDescription"))}
            </span>

            <a
                class="secondary-button"
                href="${GITHUB_RELEASES_URL}"
                target="_blank"
                rel="noopener"
            >
                ${escapeHTML(t("githubReleases"))}
                →
            </a>

        </div>

    `;
}


/* =========================================================
   RENDER RELEASE HISTORY
========================================================= */

function renderReleaseHistory() {

    const container =
        document.getElementById("releaseList");

    if (!container) {
        return;
    }


    if (!githubReleases.length) {

        showReleaseEmpty();

        return;
    }


    container.innerHTML =
        githubReleases
            .map(createReleaseCard)
            .join("");


    /*
       Re-run reveal animation for newly
       generated release cards.
    */

    initializeReveal();
}


/* =========================================================
   UPDATE LATEST RELEASE
========================================================= */

function updateLatestRelease() {

    const latest =
        githubReleases[0];

    if (!latest) {
        return;
    }


    const version =
        latest.tag_name ||
        latest.name ||
        "Unknown";


    const apk =
        findAPK(latest);


    const displayVersion =
        version;


    /* Hero version */

    const heroVersion =
        document.getElementById(
            "heroVersion"
        );

    if (heroVersion) {
        heroVersion.textContent =
            displayVersion;
    }


    /* Banner */

    const bannerVersion =
        document.getElementById(
            "bannerVersion"
        );

    if (bannerVersion) {

        bannerVersion.textContent =
            `Mor Panchayat ${displayVersion}`;

    }


    /* Latest title */

    const latestVersionTitle =
        document.getElementById(
            "latestVersionTitle"
        );

    if (latestVersionTitle) {

        latestVersionTitle.textContent =
            displayVersion;

    }


    /* Latest version */

    const latestVersion =
        document.getElementById(
            "latestVersion"
        );

    if (latestVersion) {

        latestVersion.textContent =
            `${displayVersion}${
                latest.prerelease
                    ? " Beta"
                    : ""
            }`;

    }


    /* Update card */

    const updateCardVersion =
        document.getElementById(
            "updateCardVersion"
        );

    if (updateCardVersion) {

        updateCardVersion.textContent =
            `${displayVersion}${
                latest.prerelease
                    ? " Beta"
                    : ""
            }`;

    }


    /* Hero download */

    const heroDownload =
        document.getElementById(
            "heroDownload"
        );

    /* Banner download */

    const bannerDownload =
        document.getElementById(
            "bannerDownload"
        );

    /* Latest download */

    const latestDownload =
        document.getElementById(
            "latestDownload"
        );

    /* Final download */

    const finalDownload =
        document.getElementById(
            "finalDownload"
        );


    const downloadButtons = [
        heroDownload,
        bannerDownload,
        latestDownload,
        finalDownload
    ];


    downloadButtons.forEach(button => {

        if (!button) {
            return;
        }


        if (apk) {

            button.href =
                apk.browser_download_url;

            button.removeAttribute(
                "aria-disabled"
            );

            button.classList.remove(
                "disabled"
            );

        } else {

            button.href =
                latest.html_url;

            button.removeAttribute(
                "download"
            );

        }

    });
}


/* =========================================================
   FETCH ALL GITHUB RELEASES
========================================================= */

async function fetchAllGitHubReleases() {

    const allReleases = [];

    let page = 1;


    /*
       GitHub allows up to 100 releases per page.
       We continue fetching until a page contains
       fewer than 100 results.
    */

    while (true) {

        const response =
            await fetch(
                `${GITHUB_RELEASES_API}&page=${page}`,
                {
                    headers: {
                        Accept:
                            "application/vnd.github+json"
                    },
                    cache: "no-store"
                }
            );


        if (!response.ok) {

            throw new Error(
                `GitHub API error: ${response.status}`
            );

        }


        const releases =
            await response.json();


        if (!Array.isArray(releases)) {
            throw new Error(
                "Invalid GitHub response."
            );
        }


        allReleases.push(
            ...releases
        );


        if (releases.length < 100) {
            break;
        }


        page++;


        /*
           Safety limit.
           This prevents an accidental infinite loop.
        */

        if (page > 10) {
            break;
        }

    }


    return allReleases;
}


/* =========================================================
   LOAD GITHUB RELEASES
========================================================= */

async function loadGitHubReleases() {

    showReleaseLoading();


    try {

        const releases =
            await fetchAllGitHubReleases();


        /*
           Remove draft releases.
           GitHub normally does not expose drafts
           to unauthenticated public requests.
        */

        githubReleases =
            releases
                .filter(release =>
                    !release.draft
                )
                .sort(compareVersions);


        renderReleaseHistory();

        updateLatestRelease();


    } catch (error) {

        console.error(
            "Mor Panchayat GitHub Releases:",
            error
        );


        showReleaseError();

    }
}


/* =========================================================
   LANGUAGE
========================================================= */

function updateStaticTranslations() {

    document.querySelectorAll(
        "[data-i18n]"
    ).forEach(element => {

        const key =
            element.getAttribute(
                "data-i18n"
            );

        if (!key) {
            return;
        }


        /*
           Only replace text if the translation
           actually exists.
        */

        if (
            translations[currentLanguage] &&
            translations[currentLanguage][key]
        ) {

            element.textContent =
                translations[currentLanguage][key];

        }

    });


    const languageButton =
        document.getElementById(
            "languageToggle"
        );


    if (languageButton) {

        languageButton.setAttribute(
            "aria-label",
            currentLanguage === "en"
                ? "Switch to Hindi"
                : "Switch to English"
        );

    }

}


/* =========================================================
   LANGUAGE TOGGLE
========================================================= */

function initializeLanguage() {

    const button =
        document.getElementById(
            "languageToggle"
        );

    if (!button) {
        return;
    }


    updateStaticTranslations();


    button.addEventListener(
        "click",
        () => {

            currentLanguage =
                currentLanguage === "en"
                    ? "hi"
                    : "en";


            localStorage.setItem(
                "morPanchayatLanguage",
                currentLanguage
            );


            updateStaticTranslations();


            /*
               Re-render release dates and
               release labels in the selected language.
            */

            renderReleaseHistory();


            updateLatestRelease();

        }
    );

}


/* =========================================================
   NAVBAR
========================================================= */

function initializeNavbar() {

    const navbar =
        document.querySelector(
            ".navbar"
        );


    if (!navbar) {
        return;
    }


    function updateNavbar() {

        navbar.classList.toggle(
            "scrolled",
            window.scrollY > 30
        );

    }


    window.addEventListener(
        "scroll",
        updateNavbar,
        {
            passive: true
        }
    );


    updateNavbar();
}


/* =========================================================
   MOBILE MENU
========================================================= */

function initializeMobileMenu() {

    const menuButton =
        document.getElementById(
            "menuButton"
        );

    const mobileMenu =
        document.getElementById(
            "mobileMenu"
        );


    if (!menuButton || !mobileMenu) {
        return;
    }


    menuButton.addEventListener(
        "click",
        () => {

            mobileMenu.classList.toggle(
                "open"
            );

        }
    );


    mobileMenu
        .querySelectorAll("a")
        .forEach(link => {

            link.addEventListener(
                "click",
                () => {

                    mobileMenu.classList.remove(
                        "open"
                    );

                }
            );

        });
}


/* =========================================================
   SCROLL REVEAL
========================================================= */

function initializeReveal() {

    const elements =
        document.querySelectorAll(
            ".reveal:not(.visible)"
        );


    if (!elements.length) {
        return;
    }


    if (
        !("IntersectionObserver" in window)
    ) {

        elements.forEach(
            element =>
                element.classList.add(
                    "visible"
                )
        );

        return;
    }


    const observer =
        new IntersectionObserver(
            entries => {

                entries.forEach(
                    entry => {

                        if (
                            entry.isIntersecting
                        ) {

                            entry.target.classList.add(
                                "visible"
                            );

                            observer.unobserve(
                                entry.target
                            );

                        }

                    }
                );

            },
            {
                threshold: 0.1
            }
        );


    elements.forEach(
        element =>
            observer.observe(
                element
            )
    );
}


/* =========================================================
   SMOOTH ANCHOR NAVIGATION
========================================================= */

function initializeSmoothNavigation() {

    document.querySelectorAll(
        'a[href^="#"]'
    ).forEach(link => {

        link.addEventListener(
            "click",
            event => {

                const targetId =
                    link.getAttribute(
                        "href"
                    );


                if (
                    !targetId ||
                    targetId === "#"
                ) {
                    return;
                }


                const target =
                    document.querySelector(
                        targetId
                    );


                if (!target) {
                    return;
                }


                event.preventDefault();


                const navbar =
                    document.querySelector(
                        ".navbar"
                    );


                const navbarHeight =
                    navbar
                        ? navbar.offsetHeight
                        : 0;


                const targetPosition =
                    target.getBoundingClientRect()
                        .top +
                    window.scrollY -
                    navbarHeight -
                    15;


                window.scrollTo({

                    top:
                        targetPosition,

                    behavior:
                        "smooth"

                });

            }
        );

    });
}


/* =========================================================
   CURRENT YEAR
========================================================= */

function initializeYear() {

    const year =
        document.getElementById(
            "currentYear"
        );

    if (year) {

        year.textContent =
            new Date().getFullYear();

    }
}


/* =========================================================
   DOWNLOAD TRACKING
========================================================= */

function initializeDownloadTracking() {

    document.addEventListener(
        "click",
        event => {

            const link =
                event.target.closest(
                    'a[href*=".apk"]'
                );


            if (!link) {
                return;
            }


            console.log(
                "Mor Panchayat APK download started."
            );

        }
    );
}


/* =========================================================
   KEYBOARD ACCESSIBILITY
========================================================= */

function initializeKeyboard() {

    document.addEventListener(
        "keydown",
        event => {

            if (
                event.key !== "Escape"
            ) {
                return;
            }


            const mobileMenu =
                document.getElementById(
                    "mobileMenu"
                );


            if (mobileMenu) {

                mobileMenu.classList.remove(
                    "open"
                );

            }

        }
    );
}


/* =========================================================
   INITIALIZE WEBSITE
========================================================= */

document.addEventListener(
    "DOMContentLoaded",
    async () => {

        initializeNavbar();

        initializeMobileMenu();

        initializeLanguage();

        initializeReveal();

        initializeSmoothNavigation();

        initializeYear();

        initializeDownloadTracking();

        initializeKeyboard();

        /*
           This is the important part:
           fetch real GitHub Releases.
        */

        await loadGitHubReleases();

    }
);
