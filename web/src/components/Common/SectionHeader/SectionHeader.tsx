import styles from "./SectionHeader.module.css"

function SectionHeader({title}: {title: string}) {
    return (
        <div className={styles.SectionHeader}>
            <h1>{title}</h1>
        </div>
    );
}

export default SectionHeader;