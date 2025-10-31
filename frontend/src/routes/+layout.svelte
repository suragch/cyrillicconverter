<script lang="ts">
    import '../app.css'; // Import global Tailwind CSS
</script>

<div class="min-h-screen bg-white text-near-black flex flex-col items-center p-4 sm:p-8 font-inter">
    <main class="w-full max-w-7xl flex-grow">
        <slot />
    </main>
</div>