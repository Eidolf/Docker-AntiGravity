document.addEventListener('DOMContentLoaded', () => {
    // Generate floating elements
    const container = document.getElementById('floating-container');
    const shapeCount = 15;

    for (let i = 0; i < shapeCount; i++) {
        const shape = document.createElement('div');
        shape.classList.add('floating-shape');

        // Randomize
        const size = Math.random() * 60 + 20;
        const left = Math.random() * 100;
        const duration = Math.random() * 15 + 10;
        const delay = Math.random() * 5;
        const opacity = Math.random() * 0.3 + 0.1;

        shape.style.width = `${size}px`;
        shape.style.height = `${size}px`;
        shape.style.left = `${left}%`;
        shape.style.bottom = '-100px'; // Start below screen
        shape.style.position = 'absolute';
        shape.style.background = `rgba(255, 255, 255, ${opacity})`;
        shape.style.borderRadius = Math.random() > 0.5 ? '50%' : '10%'; // Circle or rounded square
        shape.style.backdropFilter = 'blur(5px)';
        shape.style.animation = `floatUp ${duration}s linear infinite`;
        shape.style.animationDelay = `-${delay}s`;

        container.appendChild(shape);
    }
});

function copyCommand() {
    const command = 'docker run -d -p 6080:6080 ghcr.io/eidolf/docker-antigravity:latest';
    navigator.clipboard.writeText(command).then(() => {
        const btn = document.querySelector('.copy-btn');


        btn.innerHTML = `<span id="copy-icon">✅</span> Copied!`;
        btn.style.color = '#00ff9d';

        setTimeout(() => {
            btn.innerHTML = `<span id="copy-icon">📋</span> Copy`;
            btn.style.color = '';
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy text: ', err);
    });
}
window.copyCommand = copyCommand;

// Add keyframes dynamically
const style = document.createElement('style');
style.innerHTML = `
    @keyframes floatUp {
        0% { transform: translateY(0) rotate(0deg); opacity: 0; }
        10% { opacity: 1; }
        90% { opacity: 1; }
        100% { transform: translateY(-110vh) rotate(360deg); opacity: 0; }
    }
`;
document.head.appendChild(style);
